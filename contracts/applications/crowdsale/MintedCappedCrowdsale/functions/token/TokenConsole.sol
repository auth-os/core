pragma solidity ^0.4.23;

import "../../../../../lib/MemoryBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library TokenConsole {

  using MemoryBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 internal constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the sale is ready to run
  bytes32 internal constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the amount of tokens sold in the crowdsale so far. Does not include reserved tokens
  bytes32 internal constant CROWDSALE_TOKENS_SOLD = keccak256("crowdsale_tokens_sold");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 internal constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  /// TOKEN STORAGE ///

  // Storage location for token totalSupply
  bytes32 internal constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 internal constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  // Whether or not the token is unlocked for transfers
  bytes32 internal constant TOKENS_ARE_UNLOCKED = keccak256("tokens_are_unlocked");

  /// Storage location for an array of addresses with some form of reserved tokens
  bytes32 internal constant TOKEN_RESERVED_DESTINATIONS = keccak256("token_reserved_dest_list");

  // Storage seed for reserved token information for a given address
  // Maps an address for which tokens are reserved to a struct:
  // ReservedInfo { uint destination_list_index; uint num_tokens; uint num_percent; uint percent_decimals; }
  // destination_list_index is the address's index in TOKEN_RESERVED_DESTINATIONS, plus 1. 0 means the address is not in the list
  bytes32 internal constant TOKEN_RESERVED_ADDR_INFO = keccak256("token_reserved_addr_info");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 internal constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /*
  Allows the admin to set an address's transfer agent status - transfer agents can transfer tokens prior to the end of the crowdsale

  @param _agent: The address whose transfer agent status will be updated
  @param _is_transfer_agent: If true, address will be set as a transfer agent
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function setTransferAgentStatus(address _agent, bool _is_transfer_agent, bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (_agent == address(0))
      bytes32("InvalidTransferAgent").trigger();

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'read' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_SING);
    // Place exec id and admin storage address location in memory
    ptr.cdPush(exec_id);
    ptr.cdPush(ADMIN);

    // Read from storage and store return in buffer -
    // Check that sender is equal to the returned admin address
    if (bytes32(sender) != ptr.readSingle())
      bytes32("SenderIsNotAdmin").trigger();

    // Sender is admin address - create storage buffer (overwrite previous read buffer), and set return values -
    ptr.stOverwrite(0, 0);
    // Push address transfer agent status storage location in storage buffer, followed by the passed-in status
    ptr.stPush(keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS), _is_transfer_agent ? bytes32(1) : bytes32(0));

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Allows the admin to set multiple reserved token destinations for a crowdsale, which will be awarded at crowdsale finalization
  Each array index corresponds to the same indices in the other arrays
  If an address is repeated in _destinations, it will be ignored

  @param _destinations: An array of addresses for which tokens will be reserved
  @param _num_tokens: An array of token amounts to reserve for each address
  @param _num_percents: An array of percentages to reserve for each address. Percents are calculated as percent of tokens existing at end of crowdsale
  @param _percent_decimals: An array of decimal amounts coresponding to each percentage - used for precision
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function updateMultipleReservedTokens(
    address[] memory _destinations,
    uint[] memory _num_tokens,
    uint[] memory _num_percents,
    uint[] memory _percent_decimals,
    bytes memory _context
  ) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (
      _destinations.length != _num_tokens.length
      || _num_tokens.length != _num_percents.length
      || _num_percents.length != _percent_decimals.length
      || _destinations.length == 0
    ) bytes32("InvalidInputArray").trigger();

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    // Reading data for all input destinations, as well as crowdsale destinations list length, crowdsale admin address permission, and crowdsale initialization status locations
    ptr.cdPush(bytes32(3 + _destinations.length));
    // Push crowdsale admin address permission location to buffer
    ptr.cdPush(ADMIN);
    // Push crowdsale initialization status locaiton to buffer
    ptr.cdPush(CROWDSALE_IS_INIT);
    // Add crowdsale destinations list length location to buffer
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    // Loop over destinations, calculate their reserved token data storage location, and add to buffer
    for (uint i = 0; i < _destinations.length ; i++) {
      // Ensure no invalid submitted addresses
      if (_destinations[i] == address(0)) bytes32("InvalidDestination").trigger();
      // Destination list index for all addresses is the first slot in the reserved address struct - no need to add an offset
      ptr.cdPush(keccak256(keccak256(_destinations[i]), TOKEN_RESERVED_ADDR_INFO));
    }
    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = ptr.readMulti();
    // Ensure correct read length -
    assert(read_values.length == 3 + _destinations.length);

    // Ensure sender is admin address, and crowdsale has not been initialized
    if (read_values[0] != bytes32(sender) || read_values[1] != 0)
      bytes32("NotAdminOrSaleIsInit").trigger();

    // Create buffer for store_data return value
    ptr = MemoryBuffers.stBuff(0, 0);

    // Loop over read_values and input arrays - for each address which is unique within the passed-in destinations list,
    // place its reservation information in the storage buffer. Ignore duplicates in passed-in array.
    // For every address which is not a local duplicate, and also does not exist yet in the crowdsale storage reserved destination list,
    // push it to the end of the list and increment list length (in storage buffer)
    // Addresses with nonzero values in read_values are already a 'reserved token destination' in storage
    // First 3 indices in read_values are admin address, crowdsale init status, and crowdsale reserved destinations list length - begin
    // reading destinations address indices from read_values[3]

    for (i = 3; i < read_values.length; i++) {
      // If value is 0, address has not already been added to the crowdsale destinations list in storage
      address to_add = _destinations[i - 3];
      if (read_values[i] == 0) {
        // Now, check the passed-in _destinations list to see if this address is listed multiple times in the input, as we only want to store information on unique addresses
        for (uint j = _destinations.length - 1; j > i - 3; j--) {
          // address is not unique locally - found the same address in _destinations
          if (_destinations[j] == to_add) {
            to_add = address(0);
            break;
          }
        }

        // If is_unique is zero, this address is not unique within the passed-in list - skip any additions to storage buffer
        if (to_add == address(0))
          continue;

        // Increment length
        read_values[2] = bytes32(uint(read_values[2]) + 1);
        // Ensure reserved destination amount does not exceed 20
        require(uint(read_values[2]) <= 20);
        // Get storage position (end of TOKEN_RESERVED_DESTINATIONS list), and push to buffer
        ptr.stPush(
          bytes32(32 * uint(read_values[2]) + uint(TOKEN_RESERVED_DESTINATIONS)),
          bytes32(to_add)
        );
        // Store reservation information in struct at TOKEN_RESERVED_ADDR_INFO
        ptr.stPush(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO), read_values[2]);
      }

      // Push reservation information to storage request buffer
      ptr.stPush(
        bytes32(32 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))),
        bytes32(_num_tokens[i - 3])
      );
      ptr.stPush(
        bytes32(64 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))),
        bytes32(_num_percents[i - 3])
      );
      ptr.stPush(
        bytes32(96 + uint(keccak256(keccak256(to_add), TOKEN_RESERVED_ADDR_INFO))),
        bytes32(_percent_decimals[i - 3])
      );
    }
    // Finally, push new array length to storage buffer
    ptr.stPush(TOKEN_RESERVED_DESTINATIONS, read_values[2]);

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Allows the admin to remove reserved tokens for a destination, prior to crowdsale initialization

  @param _destination: The address whos reserved listing will be removed
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function removeReservedTokens(address _destination, bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (_destination == address(0))
      bytes32("InvalidDestination").trigger();

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Place admin address, crowdsale initialization status, reserved token list length, and _destination list index storage locations in callata
    ptr.cdPush(ADMIN);
    ptr.cdPush(CROWDSALE_IS_INIT);
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    ptr.cdPush(keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO));
    // Read from storage, and store returned values in buffer
    bytes32[] memory read_values = ptr.readMulti();
    // Ensure the length is 4
    assert(read_values.length == 4);

    // Ensure sender is admin address, and crowdsale has not been initialized
    if (read_values[0] != bytes32(sender) || read_values[1] != 0)
      bytes32("NotAdminOrSaleIsInit").trigger();

    // Get reservation list length
    uint reservation_len = uint(read_values[2]);
    // Get index of passed-in destination. If zero, sender is not in reserved list - revert
    uint to_remove = uint(read_values[3]);
    // Ensure that to_remove is less than or equal to reservation list length (stored indices are offset by 1)
    assert(to_remove <= reservation_len && to_remove != 0);

    // If to_remove is the final index in the list, decrement the length and remove their reserved token information struct
    if (to_remove == reservation_len) {
      // Overwrite previous buffer, and create storage return buffer
      ptr.stOverwrite(0, 0);

    } else {
      // to_remove is not the final index in the list - read the address stored at the final index in the list -

      // Overwrite previous 'readMulti' calldata buffer with a 'read' buffer
      ptr.cdOverwrite(RD_SING);
      // Push exec id to buffer
      ptr.cdPush(exec_id);
      // Push final index of reserved list location to calldata buffer
      ptr.cdPush(bytes32(32 * reservation_len + uint(TOKEN_RESERVED_DESTINATIONS)));
      // Execute read from storage, and store return in buffer
      address last_index = address(ptr.readSingle());

      // Overwrite buffer and create storage return buffer
      ptr.stOverwrite(0, 0);

      // Push updated index (to_remove) for the address that was the final index in the destination list
      ptr.stPush(keccak256(keccak256(last_index), TOKEN_RESERVED_ADDR_INFO), bytes32(to_remove));
      // Push last index address to correct spot in TOKEN_RESERVED_DESTINATIONS list
      ptr.stPush(bytes32((32 * to_remove) + uint(TOKEN_RESERVED_DESTINATIONS)), bytes32(last_index));
    }
    // Push new destinations list length to storage buffer
    ptr.stPush(TOKEN_RESERVED_DESTINATIONS, bytes32(reservation_len - 1));
    // Push removed address's list index location and new value (0) to storage buffer
    ptr.stPush(keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO), 0);

    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Allows anyone to distribute reserved tokens to their respective destinations following the finalization of the crowdsale
  Providing an amount of tokens to distribute allows for batched distribution - given a long list, it may be costly to send the entire list at once
  Once tokens for an address are distributed, the list's length is decremented

  @param _amt: The number of indices in the reserved tokens list to distribute (allows for batching)
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function distributeReservedTokens(uint _amt, bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (_amt == 0)
      bytes32("InvalidAmt").trigger();

    // Parse context array and get sender address and execution id
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Place crowdsale finalization status, total tokens sold, total token supply, and reserved destination length storage locations to calldata
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    ptr.cdPush(CROWDSALE_TOKENS_SOLD);
    ptr.cdPush(TOKEN_TOTAL_SUPPLY);
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    // Read from storage, and store returned values in buffer
    bytes32[] memory initial_read_values = ptr.readMulti();
    // Ensure the length is 4
    assert(initial_read_values.length == 4);

    // If the crowdsale is not finalized, revert
    if (initial_read_values[0] == 0)
      bytes32("CrowdsaleNotFinalized").trigger();

    // Get total tokens sold, total token supply, and reserved destinations list length
    uint total_sold = uint(initial_read_values[1]);
    uint total_supply = uint(initial_read_values[2]);
    uint num_destinations = uint(initial_read_values[3]);

    // If _amt is greater than the reserved destinations list length, set amt equal to the list length
    if (_amt > num_destinations)
      _amt = num_destinations;

    // Overwrite calldata pointer to create new 'readMulti' request
    ptr.cdOverwrite(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(_amt));
    // Get the locations of all destinations to be paid out, starting with the last destination and working backward (this allows us to simply decrement the length, instead of swapping entries)
    for (uint i = 0; i < _amt; i++) {
      // Get end of list (32 * num_destinations) and subtract multiples of i to get each consecutive index
      ptr.cdPush(bytes32(32 * (num_destinations - i) + uint(TOKEN_RESERVED_DESTINATIONS)));
    }
    // Read from storage, and store returned values in buffer
    initial_read_values = ptr.readMulti();
    // Ensure valid return length -
    assert(initial_read_values.length == _amt);

    // Finally - for each returned address, we want to read the reservation information for that address as well as that address's current token balance -

    // Create a new 'readMulti' buffer - we don't want to overwrite addresses
    ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4 * _amt));
    // For each address returned, place the locations of their balance, reserved tokens, reserved percents, and percent's precision in 'readMulti' buffer
    for (i = 0; i < _amt; i++) {
      // Destination balance location
      ptr.cdPush(keccak256(keccak256(initial_read_values[i]), TOKEN_BALANCES));
      // Number of tokens reserved
      ptr.cdPush(
        bytes32(
          32 + uint(keccak256(keccak256(address(initial_read_values[i])), TOKEN_RESERVED_ADDR_INFO))
        )
      );
      // Number of percent reserved - location is 32 bytes after number of tokens reserved
      ptr.cdPush(
        bytes32(
          64 + uint(keccak256(keccak256(address(initial_read_values[i])), TOKEN_RESERVED_ADDR_INFO))
        )
      );
      // Precision of percent - location is 32 bytes after number of percentage points reserved
      ptr.cdPush(
        bytes32(
          96 + uint(keccak256(keccak256(address(initial_read_values[i])), TOKEN_RESERVED_ADDR_INFO))
        )
      );
    }
    // Read from storage, and store return in buffer
    uint[] memory read_reserved_info = ptr.readMulti().toUintArr();
    // Ensure valid return length -
    assert(read_reserved_info.length == 4 * _amt);

    // Create storage buffer in free memory, to set up return value
    ptr = MemoryBuffers.stBuff(0, 0);
    // Push new list length to storage buffer
    ptr.stPush(TOKEN_RESERVED_DESTINATIONS, bytes32(num_destinations - _amt));
    // For each address, get their new balance and add to storage buffer
    for (i = 0; i < _amt; i++) {
      // Get percent reserved and precision
      uint to_add = read_reserved_info[(i * 4) + 2];
      // Two points of precision are added to ensure at least a percent out of 100
      uint precision = 2 + read_reserved_info[(i * 4) + 3];
      // Get percent divisor
      precision = 10 ** precision;

      // Get number of tokens to add from total_sold and precent reserved
      to_add = total_sold * to_add / precision;

      // Add number of tokens reserved, and check for overflow
      // Additionally, check that the added amount does not overflow total supply
      require(to_add + read_reserved_info[(i * 4) + 1] >= to_add);
      to_add += read_reserved_info[(i * 4) + 1];
      require(total_supply + to_add >= total_supply);
      // Increment total supply
      total_supply += to_add;

      // Add destination's current token balance to to_add, and check for overflow
      require(to_add + read_reserved_info[i * 4] >= read_reserved_info[i * 4]);
      to_add += read_reserved_info[i * 4];
      // Add new balance and balance location to storage buffer
      ptr.stPush(keccak256(keccak256(address(initial_read_values[i])), TOKEN_BALANCES), bytes32(to_add));
    }
    // Add new total supply to storage buffer
    ptr.stPush(TOKEN_TOTAL_SUPPLY, bytes32(total_supply));
    // Get bytes32[] representation of storage buffer
    store_data = ptr.getBuffer();
  }

  /*
  Allows the admin to finalize the crowdsale, distribute reserved tokens, and unlock the token for transfer

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function finalizeCrowdsaleAndToken(bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Get sender and exec id for this app instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(3));
    // Push admin address, crowdsale init status, and crowdsale finalization status in calldata
    ptr.cdPush(ADMIN);
    ptr.cdPush(CROWDSALE_IS_INIT);
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    // Read from storage, and store returned data in buffer
    bytes32[] memory read_values = ptr.readMulti();
    // Ensure correct return length
    assert(read_values.length == 3);

    // Check that the sender is the admin address, and that the crowdsale is initialized, but not finalized
    if (
      read_values[0] != bytes32(sender)
      || read_values[1] == 0                          // Crowdsale init status is false
      || read_values[2] == bytes32(1)                 // Crowdsale finalization status is true
    ) bytes32("NotAdminOrStatusInvalid").trigger();

    // Get reserved token distribution from distributeAndUnlockTokens
    ptr = distributeAndUnlockTokens(exec_id);
    // Push crowdsale finalization status to buffer
    ptr.stPush(CROWDSALE_IS_FINALIZED, bytes32(1));

    // Get bytes32[] storage request array from buffer
    store_data = ptr.getBuffer();
  }

  /*
  Returns the store_data array for reserved token distribution

  @param _exec_id: The execution id associate with this crowdsale
  @return ptr: A pointer to a storage return buffer
  */
  function distributeAndUnlockTokens(bytes32 _exec_id) internal view returns (uint ptr) {
    // Create 'readMulti' calldata buffer in memory
    ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(3));
    // Place total tokens sold, total token supply, and reserved destination length storage locations to calldata
    ptr.cdPush(CROWDSALE_TOKENS_SOLD);
    ptr.cdPush(TOKEN_TOTAL_SUPPLY);
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    // Read from storage, and store returned values in buffer
    uint[] memory initial_read_values = ptr.readMulti().toUintArr();
    // Ensure the length is 4
    assert(initial_read_values.length == 3);

    // Get total tokens sold, total token supply, and reserved destinations list length
    uint total_sold = initial_read_values[0];
    uint total_supply = initial_read_values[1];
    uint num_destinations = initial_read_values[2];

    // If there are no reserved destinations, simply create a storage buffer to unlock token transfers -
    if (num_destinations == 0) {
      ptr = MemoryBuffers.stBuff(0, 0);
      // Unlock tokens by adding token 'unlock' status to storage buffer
      ptr.stPush(TOKENS_ARE_UNLOCKED, bytes32(1));
      // Return pointer
      return ptr;
    }

    // Overwrite calldata pointer to create new 'readMulti' request
    ptr.cdOverwrite(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_destinations));
    // Get the locations of all destinations to be paid out
    for (uint i = 0; i < num_destinations; i++)
      ptr.cdPush(bytes32(32 + (32 * i) + uint(TOKEN_RESERVED_DESTINATIONS)));

    // Read from storage, and store returned values in buffer
    address[] memory reserved_addresses = ptr.readMulti().toAddressArr();
    // Ensure valid return length -
    assert(reserved_addresses.length == num_destinations);

    // Finally - for each returned address, we want to read the reservation information for that address as well as that address's current token balance -

    // Create a new 'readMulti' buffer - we don't want to overwrite addresses
    ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4 * num_destinations));
    // For each address returned, place the locations of their balance, reserved tokens, reserved percents, and percent's precision in 'readMulti' buffer
    for (i = 0; i < num_destinations; i++) {
      // Destination balance location
      ptr.cdPush(keccak256(keccak256(reserved_addresses[i]), TOKEN_BALANCES));
      // Number of tokens reserved
      ptr.cdPush(bytes32(32 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
      // Number of percent reserved - location is 32 bytes after number of tokens reserved
      ptr.cdPush(bytes32(64 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
      // Precision of percent - location is 32 bytes after number of percentage points reserved
      ptr.cdPush(bytes32(96 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
    }
    // Read from storage, and store return in buffer
    initial_read_values = ptr.readMulti().toUintArr();
    // Ensure valid return length -
    assert(initial_read_values.length == 4 * num_destinations);

    // Create storage buffer in free memory, to set up return value
    ptr = MemoryBuffers.stBuff(0, 0);
    // Push new list length to storage buffer
    ptr.stPush(TOKEN_RESERVED_DESTINATIONS, 0);
    // For each address, get their new balance and add to storage buffer
    for (i = 0; i < num_destinations; i++) {
      // Get percent reserved and precision
      uint to_add = initial_read_values[(i * 4) + 2];
      // Two points of precision are added to ensure at least a percent out of 100
      uint precision = 2 + initial_read_values[(i * 4) + 3];
      // Get percent divisor
      precision = 10 ** precision;

      // Get number of tokens to add from total_sold and precent reserved
      to_add = total_sold * to_add / precision;

      // Add number of tokens reserved, and check for overflow
      // Additionally, check that the added amount does not overflow total supply
      require(to_add + initial_read_values[(i * 4) + 1] >= to_add);
      to_add += initial_read_values[(i * 4) + 1];
      require(total_supply + to_add >= total_supply);
      // Increment total supply
      total_supply += to_add;

      // Add destination's current token balance to to_add, and check for overflow
      require(to_add + initial_read_values[i * 4] >= initial_read_values[i * 4]);
      to_add += initial_read_values[i * 4];
      // Add new balance and balance location to storage buffer
      ptr.stPush(keccak256(keccak256(reserved_addresses[i]), TOKEN_BALANCES), bytes32(to_add));
    }
    // Add new total supply to storage buffer
    ptr.stPush(TOKEN_TOTAL_SUPPLY, bytes32(total_supply));
    // Unlock tokens by adding token 'unlock' status to storage buffer
    ptr.stPush(TOKENS_ARE_UNLOCKED, bytes32(1));
  }

  /*
  If the crowdsale is finalized, allows anyone to unlock token transfers and distribute reserved tokens

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sents
  */
  function finalizeAndDistributeToken(bytes memory _context) public view returns (bytes32[] memory store_data) {
    // Get sender and exec id for this app instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Create 'readMulti' calldata buffer in memory
    uint ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Place total tokens sold, total token supply, and reserved destination length storage locations to calldata
    ptr.cdPush(CROWDSALE_TOKENS_SOLD);
    ptr.cdPush(TOKEN_TOTAL_SUPPLY);
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    // Push crowdsale finalization status location to buffer
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    // Read from storage, and store returned values in buffer
    uint[] memory initial_read_values = ptr.readMulti().toUintArr();
    // Ensure the length is 4
    assert(initial_read_values.length == 4);

    // Get total tokens sold, total token supply, and reserved destinations list length
    uint total_sold = initial_read_values[0];
    uint total_supply = initial_read_values[1];
    uint num_destinations = initial_read_values[2];

    // If the crowdsale is not finalized, revert
    if (initial_read_values[3] == 0)
      bytes32("CrowdsaleNotFinalized").trigger();

    // If there are no reserved destinations, simply create a storage buffer to unlock token transfers -
    if (num_destinations == 0) {
      ptr = MemoryBuffers.stBuff(0, 0);
      // Unlock tokens by adding token 'unlock' status to storage buffer
      ptr.stPush(TOKENS_ARE_UNLOCKED, bytes32(1));
      // Return storage request
      store_data = ptr.getBuffer();
      return store_data;
    }

    // Overwrite calldata pointer to create new 'readMulti' request
    ptr.cdOverwrite(RD_MULTI);
    // Place exec id, data read offset, and read size in buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_destinations));
    // Get the locations of all destinations to be paid out
    for (uint i = 0; i < num_destinations; i++)
      ptr.cdPush(bytes32(32 + (32 * i) + uint(TOKEN_RESERVED_DESTINATIONS)));

    // Read from storage, and store returned values in buffer
    address[] memory reserved_addresses = ptr.readMulti().toAddressArr();
    // Ensure valid return length -
    assert(reserved_addresses.length == num_destinations);

    // Finally - for each returned address, we want to read the reservation information for that address as well as that address's current token balance -

    // Create a new 'readMulti' buffer - we don't want to overwrite addresses
    ptr = MemoryBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4 * num_destinations));
    // For each address returned, place the locations of their balance, reserved tokens, reserved percents, and percent's precision in 'readMulti' buffer
    for (i = 0; i < num_destinations; i++) {
      // Destination balance location
      ptr.cdPush(keccak256(keccak256(reserved_addresses[i]), TOKEN_BALANCES));
      // Number of tokens reserved
      ptr.cdPush(bytes32(32 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
      // Number of percent reserved - location is 32 bytes after number of tokens reserved
      ptr.cdPush(bytes32(64 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
      // Precision of percent - location is 32 bytes after number of percentage points reserved
      ptr.cdPush(bytes32(96 + uint(keccak256(keccak256(reserved_addresses[i]), TOKEN_RESERVED_ADDR_INFO))));
    }
    // Read from storage, and store return in buffer
    initial_read_values = ptr.readMulti().toUintArr();
    // Ensure valid return length -
    assert(initial_read_values.length == 4 * num_destinations);

    // Create storage buffer in free memory, to set up return value
    ptr = MemoryBuffers.stBuff(0, 0);
    // Push new list length to storage buffer
    ptr.stPush(TOKEN_RESERVED_DESTINATIONS, 0);
    // For each address, get their new balance and add to storage buffer
    for (i = 0; i < num_destinations; i++) {
      // Get percent reserved and precision
      uint to_add = initial_read_values[(i * 4) + 2];
      // Two points of precision are added to ensure at least a percent out of 100
      uint precision = 2 + initial_read_values[(i * 4) + 3];
      // Get percent divisor
      precision = 10 ** precision;

      // Get number of tokens to add from total_sold and precent reserved
      to_add = total_sold * to_add / precision;

      // Add number of tokens reserved, and check for overflow
      // Additionally, check that the added amount does not overflow total supply
      require(to_add + initial_read_values[(i * 4) + 1] >= to_add);
      to_add += initial_read_values[(i * 4) + 1];
      require(total_supply + to_add >= total_supply);
      // Increment total supply
      total_supply += to_add;

      // Add destination's current token balance to to_add, and check for overflow
      require(to_add + initial_read_values[i * 4] >= initial_read_values[i * 4]);
      to_add += initial_read_values[i * 4];
      // Add new balance and balance location to storage buffer
      ptr.stPush(keccak256(keccak256(reserved_addresses[i]), TOKEN_BALANCES), bytes32(to_add));
    }
    // Add new total supply to storage buffer
    ptr.stPush(TOKEN_TOTAL_SUPPLY, bytes32(total_supply));
    // Unlock tokens by adding token 'unlock' status to storage buffer
    ptr.stPush(TOKENS_ARE_UNLOCKED, bytes32(1));

    // Get bytes32[] storage request array from buffer
    store_data = ptr.getBuffer();
  }

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes memory _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    if (_context.length != 96)
      bytes32("UnknownExecutionContext").trigger();

    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }

    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == 0)
      bytes32("UnknownExecutionContext").trigger();
  }
}
