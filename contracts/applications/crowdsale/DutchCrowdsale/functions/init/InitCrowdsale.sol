pragma solidity ^0.4.21;

library InitCrowdsale {

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 public constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of team funds wallet
  bytes32 public constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 public constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage location of the maximum number of tokens to sell
  bytes32 public constant MAX_TOKEN_SELL_CAP = keccak256("token_sell_cap");

  // Storage location for the amount of tokens still available for purchase in this crowdsale
  bytes32 public constant TOKENS_REMAINING = keccak256("crowdsale_tokens_remaining");

  // Storage location of crowdsale start time
  bytes32 public constant CROWDSALE_STARTS_AT = keccak256("crowdsale_starts_at");

  // Storage location of duration of crowdsale
  bytes32 public constant CROWDSALE_DURATION = keccak256("crowdsale_duration");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 public constant STARTING_SALE_RATE = keccak256("crowdsale_start_rate");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 public constant ENDING_SALE_RATE = keccak256("crowdsale_end_rate");

  /// TOKEN STORAGE ///

  // Storage location for token name
  bytes32 public constant TOKEN_NAME = keccak256("token_name");

  // Storage location for token ticker symbol
  bytes32 public constant TOKEN_SYMBOL = keccak256("token_symbol");

  // Storage location for token decimals
  bytes32 public constant TOKEN_DECIMALS = keccak256("token_decimals");

  // Storage location for token totalSupply
  bytes32 public constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 public constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for user allowances mapping
  bytes32 public constant TOKEN_ALLOWANCES = keccak256("token_allowances");

  // Storage seed for token 'transfer agent' status for any address
  // Transfer agents can transfer tokens, even if the crowdsale has not yet been finalized
  bytes32 public constant TOKEN_TRANSFER_AGENTS = keccak256("token_transfer_agents");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_IMPROPER_INITIALIZATION = bytes32("ImproperInitialization"); // Initialization variables invalid
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed


  /*
  Creates a dutch auction style crowdsale with initial conditions. The sender (admin) should now initialize the crowdsale's token,
  and finalize the initialization of the crowdsale, or adjust variables first

  @param _wallet: The team funds wallet, where crowdsale purchases are forwarded
  @param _total_supply: The total supply of the token
  @param _max_amount_to_sell: The maximum amount of tokens to sell during the crowdsale
  @param _starting_rate: The amount of tokens purchased per wei invested at the beginning of the crowdsale
  @param _ending_rate: The amount of tokens purchased per wei invested at the end of the crowdsale
  @param _duration: The amount of time the crowdsale will be active for. Token price decreases over this period, hitting a minimum at the ending rate
  @param _start_time: The start time of the crowdsale
  @param _admin: The address to set as crowdsale admin - is allowed to complete initialization of the crowdsale
  @return store_data: A formatted storage request
  */
  function init(address _wallet, uint _total_supply, uint _max_amount_to_sell, uint _starting_rate, uint _ending_rate, uint _duration, uint _start_time, address _admin) public view
  returns (bytes32[] store_data) {
    // Ensure valid input
    if (
      _wallet == address(0)
      || _max_amount_to_sell == 0
      || _max_amount_to_sell > _total_supply
      || _starting_rate <= _ending_rate
      || _ending_rate == 0
      || _start_time <= now
      || _duration == 0
      || _admin == address(0)
    ) triggerException(ERR_IMPROPER_INITIALIZATION);

    // Create storage data return buffer in memory
    uint ptr = stBuff();
    // Push admin address, team wallet, token sell cap, and start/end sale rates to buffer
    stPush(ptr, ADMIN);
    stPush(ptr, bytes32(_admin));
    stPush(ptr, WALLET);
    stPush(ptr, bytes32(_wallet));
    stPush(ptr, TOKENS_REMAINING);
    stPush(ptr, bytes32(_max_amount_to_sell));
    stPush(ptr, STARTING_SALE_RATE);
    stPush(ptr, bytes32(_starting_rate));
    stPush(ptr, ENDING_SALE_RATE);
    stPush(ptr, bytes32(_ending_rate));
    // Push token totalsupply, crowdsale duration, and crowdsale start time to buffer
    stPush(ptr, TOKEN_TOTAL_SUPPLY);
    stPush(ptr, bytes32(_total_supply));
    stPush(ptr, CROWDSALE_DURATION);
    stPush(ptr, bytes32(_duration));
    stPush(ptr, CROWDSALE_STARTS_AT);
    stPush(ptr, bytes32(_start_time));
    // Push admin balance and token sell cap to buffer
    stPush(ptr, keccak256(keccak256(_admin), TOKEN_BALANCES));
    stPush(ptr, bytes32(_total_supply - _max_amount_to_sell));
    stPush(ptr, MAX_TOKEN_SELL_CAP);
    stPush(ptr, bytes32(_max_amount_to_sell));

    // Get bytes32[] storage request array from buffer
    store_data = getBuffer(ptr);
  }

  /// CROWDSALE GETTERS ///

  /*
  Returns basic information on a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return wei_raised: Total amount of wei raised so far
  @return team_wallet: The address to which funds raised are forwarded
  @return is_initialized: Whether the admin has finished crowdsale initialization
  @return is_finalized: Whether the crowdsale is still accepting purchases
  */
  function getCrowdsaleInfo(address _storage, bytes32 _exec_id) public view
  returns (uint wei_raised, address team_wallet, bool is_initialized, bool is_finalized) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(4));
    // Push wei raised and team wallet storage locations to calldata buffer
    cdPush(ptr, WEI_RAISED);
    cdPush(ptr, WALLET);
    // Push crowdsale initialization and finalization status storage locations to buffer
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    // Read from storage, and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get returned data -
    wei_raised = uint(read_values[0]);
    team_wallet = address(read_values[1]);
    is_initialized = (read_values[2] == bytes32(0) ? false : true);
    is_finalized = (read_values[3] == bytes32(0) ? false : true);
  }

  /*
  Returns information on the status of the sale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return current_rate: The current rate at which tokens are being sold
  @return time_remaining: The amount of time remaining in the crowdsale
  @return tokens_remaining: The amount of tokens still available to be sold
  */
  function getCrowdsaleStatus(address _storage, bytes32 _exec_id) public view
  returns (uint current_rate, uint time_remaining, uint tokens_remaining) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(5));
    // Push crowdsale starting and ending rates, and crowdsale start time storage locations to buffer
    cdPush(ptr, STARTING_SALE_RATE);
    cdPush(ptr, ENDING_SALE_RATE);
    cdPush(ptr, CROWDSALE_STARTS_AT);
    // Push crowdsale duration and tokens left to buffer
    cdPush(ptr, CROWDSALE_DURATION);
    cdPush(ptr, TOKENS_REMAINING);
    // Read from storage, and store return in buffer
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);

    // Get return values -
    uint start_rate = read_values[0];
    uint end_rate = read_values[1];
    uint start_time = read_values[2];
    uint sale_duration = read_values[3];
    tokens_remaining = read_values[4];

    /// Get current token sale rate and time remaining -

    (current_rate, time_remaining) =
      getRateAndTimeRemaining(start_time, sale_duration, start_rate, end_rate);
  }

  /*
  Gets the current token sale rate and time remaining, given various information

  @param _start_time: The start time of the crowdsale
  @param _duration: The duration of the crowdsale
  @param _start_rate: The amount of tokens recieved per wei at the beginning of the sale
  @param _end_rate: The amount of tokens recieved per wei at the end of the sale
  @return current_rate: The current rate of tokens/wei
  @return time_remaining: The amount of time remaining in the crowdsale
  */
  function getRateAndTimeRemaining(uint _start_time, uint _duration, uint _start_rate, uint _end_rate) internal view
  returns (uint current_rate, uint time_remaining) {
    // If the sale has not started, return 0
    if (now <= _start_time)
      return (0, (_duration + _start_time - now));

    uint time_elapsed = now - _start_time;
    // If the sale has ended, return 0
    if (time_elapsed >= _duration)
      return (0, 0);

    // Crowdsale is still active -
    time_remaining = _duration - time_elapsed;
    // Calculate current rate, adding decimals for precision -
    time_elapsed *= 100;
    current_rate = (_start_rate - _end_rate) * (time_elapsed / _duration);
    current_rate /= 100; // Remove additional precision decimals
    current_rate = _start_rate - current_rate;
  }

  /*
  Returns the start time of the crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return start_time: The start time of the first tier of a crowdsale
  */
  function getCrowdsaleStartTime(address _storage, bytes32 _exec_id) public view returns (uint start_time) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and start time location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, CROWDSALE_STARTS_AT);
    // Read from storage
    start_time = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the number of tokens sold - maximum number to sell minus tokens remaining

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return tokens_sold: The number of tokens sold this crowdsale so far
  */
  function getTokensSold(address _storage, bytes32 _exec_id) public view returns (uint tokens_sold) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(2));
    // Push token sell cap and tokens remaining storage locations to buffer
    cdPush(ptr, MAX_TOKEN_SELL_CAP);
    cdPush(ptr, TOKENS_REMAINING);
    // Read from storage, and store return in buffer
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);

    // Get return value -
    tokens_sold = read_values[0] - read_values[1];
  }

  /// TOKEN GETTERS ///

  /*
  Returns the balance of an address

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _owner: The address to look up the balance of
  @return owner_balance: The token balance of the owner
  */
  function balanceOf(address _storage, bytes32 _exec_id, address _owner) public view
  returns (uint owner_balance) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and owner balance location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, keccak256(keccak256(_owner), TOKEN_BALANCES));
    // Read from storage
    owner_balance = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the amount of tokens a spender may spend on an owner's behalf

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _owner: The address allowing spends from a spender
  @param _spender: The address allowed tokens by the owner
  @return allowed: The amount of tokens that can be transferred from the owner to a location of the spender's choosing
  */
  function allowance(address _storage, bytes32 _exec_id, address _owner, address _spender) public view
  returns (uint allowed) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and spender allowance location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, keccak256(keccak256(_spender), keccak256(keccak256(_owner), TOKEN_ALLOWANCES)));
    // Read from storage
    allowed = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the number of display decimals for a token

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_decimals: The number of decimals associated with token balances
  */
  function decimals(address _storage, bytes32 _exec_id) public view
  returns (uint token_decimals) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and token decimals storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, TOKEN_DECIMALS);
    // Read from storage
    token_decimals = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the total token supply of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return total_supply: The total token supply
  */
  function totalSupply(address _storage, bytes32 _exec_id) public view
  returns (uint total_supply) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and token total supply storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, TOKEN_TOTAL_SUPPLY);
    // Read from storage
    total_supply = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the name field of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_name: The name of the token
  */
  function name(address _storage, bytes32 _exec_id) public view returns (bytes32 token_name) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and token name storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, TOKEN_NAME);
    // Read from storage
    token_name = readSingleFrom(ptr, _storage);
  }

  /*
  Returns the ticker symbol of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_symbol: The token's ticker symbol
  */
  function symbol(address _storage, bytes32 _exec_id) public view returns (bytes32 token_symbol) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and token symbol storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, TOKEN_SYMBOL);
    // Read from storage
    token_symbol = readSingleFrom(ptr, _storage);
  }

  /*
  Returns general information on a token - name, symbol, decimals, and total supply

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_name: The name of the token
  @return token_symbol: The token ticker symbol
  @return token_decimals: The display decimals for the token
  @return total_supply: The total supply of the token
  */
  function getTokenInfo(address _storage, bytes32 _exec_id) public view
  returns (bytes32 token_name, bytes32 token_symbol, uint token_decimals, uint total_supply) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(4));
    // Place token name, symbol, decimals, and total supply storage locations in buffer
    cdPush(ptr, TOKEN_NAME);
    cdPush(ptr, TOKEN_SYMBOL);
    cdPush(ptr, TOKEN_DECIMALS);
    cdPush(ptr, TOKEN_TOTAL_SUPPLY);

    // Read from storage
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);
    // Get return values -
    token_name = read_values[0];
    token_symbol = read_values[1];
    token_decimals = uint(read_values[2]);
    total_supply = uint(read_values[3]);
  }

  /*
  Returns whether or not an address is a transfer agent, meaning they can transfer tokens before the crowdsale is finalized

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @param _agent: The address about which to look up information
  @return is_transfer_agent: Whether the passed-in address is a transfer agent
  */
  function getTransferAgentStatus(address _storage, bytes32 _exec_id, address _agent) public view
  returns (bool is_transfer_agent) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and transfer agent status storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS));
    // Read from storage
    is_transfer_agent = (readSingleFrom(ptr, _storage) == bytes32(0) ? false : true);
  }

  /*
  Creates a buffer for return data storage. Buffer pointer stores the lngth of the buffer

  @return ptr: The location in memory where the length of the buffer is stored - elements stored consecutively after this location
  */
  function stBuff() internal pure returns (uint ptr) {
    assembly {
      // Get buffer location - free memory
      ptr := mload(0x40)
      // Update free-memory pointer - it's important to note that this is not actually free memory, if the pointer is meant to expand
      mstore(0x40, add(0x20, ptr))
    }
  }

  /*
  Pushes a value to the end of a storage return buffer, and updates the length

  @param _ptr: A pointer to the start of the buffer
  @param _val: The value to push to the buffer
  */
  function stPush(uint _ptr, bytes32 _val) internal pure {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push value to end of buffer (overwrites memory - be careful!)
      mstore(add(_ptr, len), _val)
      // Increment buffer length
      mstore(_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x20, _ptr), len)) {
        mstore(0x40, add(add(0x40, _ptr), len)) // Ensure free memory pointer points to the beginning of a memory slot
      }
    }
  }

  /*
  Returns the bytes32[] stored at the buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @return store_data: The return values, which will be stored
  */
  function getBuffer(uint _ptr) internal pure returns (bytes32[] store_data){
    assembly {
      // If the size stored at the pointer is not evenly divislble into 32-byte segments, this was improperly constructed
      if gt(mod(mload(_ptr), 0x20), 0) { revert (0, 0) }
      mstore(_ptr, div(mload(_ptr), 0x20))
      store_data := _ptr
    }
  }

  /*
  Creates a calldata buffer in memory with the given function selector

  @param _selector: The function selector to push to the first location in the buffer
  @return ptr: The location in memory where the length of the buffer is stored - elements stored consecutively after this location
  */
  function cdBuff(bytes4 _selector) internal pure returns (uint ptr) {
    assembly {
      // Get buffer location - free memory
      ptr := mload(0x40)
      // Place initial length (4 bytes) in buffer
      mstore(ptr, 0x04)
      // Place function selector in buffer, after length
      mstore(add(0x20, ptr), _selector)
      // Update free-memory pointer - it's important to note that this is not actually free memory, if the pointer is meant to expand
      mstore(0x40, add(0x40, ptr))
    }
  }

  /*
  Pushes a value to the end of a calldata buffer, and updates the length

  @param _ptr: A pointer to the start of the buffer
  @param _val: The value to push to the buffer
  */
  function cdPush(uint _ptr, bytes32 _val) internal pure {
    assembly {
      // Get end of buffer - 32 bytes plus the length stored at the pointer
      let len := add(0x20, mload(_ptr))
      // Push value to end of buffer (overwrites memory - be careful!)
      mstore(add(_ptr, len), _val)
      // Increment buffer length
      mstore(_ptr, len)
      // If the free-memory pointer does not point beyond the buffer's current size, update it
      if lt(mload(0x40), add(add(0x20, _ptr), len)) {
        mstore(0x40, add(add(0x2c, _ptr), len)) // Ensure free memory pointer points to the beginning of a memory slot
      }
    }
  }

  /*
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The storage address from which to read
  @return read_values: The values read from storage
  */
  function readMultiFrom(uint _ptr, address _storage) internal view returns (bytes32[] read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
      // If call succeed, get return information
      if gt(success, 0) {
        // Ensure data will not be copied beyond the pointer
        if gt(sub(returndatasize, 0x20), mload(_ptr)) { revert (0, 0) }
        // Copy returned data to pointer, overwriting it in the process
        // Copies returndatasize, but ignores the initial read offset so that the bytes32[] returned in the read is sitting directly at the pointer
        returndatacopy(_ptr, 0x20, sub(returndatasize, 0x20))
        // Set return bytes32[] to pointer, which should now have the stored length of the returned array
        read_values := _ptr
      }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Executes a 'read' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The storage address from which to read
  @return read_value: The value read from storage
  */
  function readSingleFrom(uint _ptr, address _storage) internal view returns (bytes32 read_value) {
    bool success;
    assembly {
      // Length for 'read' buffer must be 0x44
      if iszero(eq(mload(_ptr), 0x44)) { revert (0, 0) }
      // Read from storage, and store return to pointer
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), _ptr, 0x20)
      // If call succeeded, store return at pointer
      if gt(success, 0) { read_value := mload(_ptr) }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Executes a 'readMulti' function call, given a pointer to a calldata buffer

  @param _ptr: A pointer to the location in memory where the calldata for the call is stored
  @param _storage: The address to read from
  @return read_values: The values read from storage
  */
  function readMultiUintFrom(uint _ptr, address _storage) internal view returns (uint[] read_values) {
    bool success;
    assembly {
      // Minimum length for 'readMulti' - 1 location is 0x84
      if lt(mload(_ptr), 0x84) { revert (0, 0) }
      // Read from storage
      success := staticcall(gas, _storage, add(0x20, _ptr), mload(_ptr), 0, 0)
      // If call succeed, get return information
      if gt(success, 0) {
        // Ensure data will not be copied beyond the pointer
        if gt(sub(returndatasize, 0x20), mload(_ptr)) { revert (0, 0) }
        // Copy returned data to pointer, overwriting it in the process
        // Copies returndatasize, but ignores the initial read offset so that the bytes32[] returned in the read is sitting directly at the pointer
        returndatacopy(_ptr, 0x20, sub(returndatasize, 0x20))
        // Set return bytes32[] to pointer, which should now have the stored length of the returned array
        read_values := _ptr
      }
    }
    if (!success)
      triggerException(ERR_READ_FAILED);
  }

  /*
  Reverts state changes, but passes message back to caller

  @param _message: The message to return to the caller
  */
  function triggerException(bytes32 _message) internal pure {
    assembly {
      mstore(0, _message)
      revert(0, 0x20)
    }
  }
}
