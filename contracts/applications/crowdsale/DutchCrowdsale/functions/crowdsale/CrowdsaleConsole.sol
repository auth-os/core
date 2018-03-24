pragma solidity ^0.4.21;

library CrowdsaleConsole {

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

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_UNKNOWN_CONTEXT = bytes32("UnknownContext"); // Malformed '_context' array
  bytes32 public constant ERR_INSUFFICIENT_PERMISSIONS = bytes32("InsufficientPermissions"); // Action not allowed
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed

  // Modifier - will only allow access to a crowdsale's admin address
  // Additionally, crowdasle must not be initialized
  modifier onlyAdminAndNotInit(bytes _context) {
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);
    // Get sender and exec id for this instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Get storage locations for admin address and crowdsale init status
    bytes32 admin_storage = ADMIN;
    bytes32 crowdsale_init_status_storage = CROWDSALE_IS_INIT;

    // Place 'readMulti' function selector in memory
    bytes4 rd_multi = RD_MULTI;
    assembly {
      // Get pointer to free memory for calldata
      let ptr := mload(0x40)
      // Place 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place admin storage location and crowdsale status storage location in calldata
      mstore(add(0x64, ptr), admin_storage)
      mstore(add(0x84, ptr), crowdsale_init_status_storage)
      // Read from storage, and store return at pointer
      let ret := staticcall(gas, caller, ptr, 0xa4, ptr, 0x80)
      if iszero(ret) { revert (0, 0) }

      // Check that the sender is the crowdsale admin address -
      if iszero(eq(sender, mload(add(0x40, ptr)))) { revert (0, 0) }
      // Check that the crowdsale is not already initialized -
      if gt(mload(add(0x60, ptr)), 0) { revert (0, 0) }
    }
    // All checks passed - sender is crowdsale admin, and crowdsale is not initialized
    _;
  }


  /*
  Allows the admin of a crowdsale to add token information, prior to crowdsale initialization completion

  @param _name: The name of the token to initialize
  @param _symbol: The ticker symbol of the token to initialize
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function initCrowdsaleToken(bytes32 _name, bytes32 _symbol, uint _decimals, bytes _context) public onlyAdminAndNotInit(_context) view
  returns (bytes32[] store_data) {
    // Ensure valid input
    require(_name != bytes32(0) && _symbol != bytes32(0) && _decimals > 0);

    // Allocate space for return storage request -
    store_data = new bytes32[](8);

    // First two slots are blank - this function does not accept eth
    // Store token name, symbol, and decimals
    store_data[2] = TOKEN_NAME;
    store_data[3] = _name;
    store_data[4] = TOKEN_SYMBOL;
    store_data[5] = _symbol;
    store_data[6] = TOKEN_DECIMALS;
    store_data[7] = bytes32(_decimals);
  }

  /*
  Allows the admin of a crowdsale to revise crowdsale start time duration, provided the crowdsale is not already initialized

  @param _start_time: The new start time of the crowdsale
  @param _duration: The new amount of time the crowdsale is open
  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function setCrowdsaleStartAndDuration(uint _start_time, uint _duration, bytes _context) public onlyAdminAndNotInit(_context) view returns (bytes32[] store_data) {
    // Ensure valid input
    require(_start_time > now && _duration > 0);

    // Allocate space for return storage request -
    store_data = new bytes32[](6);

    // First two slots are blank - this function does not accept eth
    // Store crowdsale start and end times
    store_data[2] = CROWDSALE_STARTS_AT;
    store_data[3] = bytes32(_start_time);
    store_data[4] = CROWDSALE_DURATION;
    store_data[5] = bytes32(_duration);
  }

  struct CrowdsaleInit {
    bytes4 rd_multi;
    bytes32 admin_storage;
    bytes32 crowdsale_init_status_storage;
    bytes32 token_name_storage;
  }

  /*
  Allows the admin of a crowdsale to finalize the initialization process for this crowdsale, locking its details

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function initializeCrowdsale(bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Get sender and exec id for this app instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Place struct in memory to hold values
    CrowdsaleInit memory cr_init = CrowdsaleInit({
      rd_multi: RD_MULTI,
      admin_storage: ADMIN,
      crowdsale_init_status_storage: CROWDSALE_IS_INIT,
      token_name_storage: TOKEN_NAME
    });

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x40)
      // Place function selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(cr_init))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Place admin address, crowdsale status, and token name storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, cr_init)))
      mstore(add(0x84, ptr), mload(add(0x40, cr_init)))
      mstore(add(0xa4, ptr), mload(add(0x60, cr_init)))
      // Read from storage, check return, and store value at pointer
      let ret := staticcall(gas, caller, ptr, 0xc4, ptr, 0xa0)
      if iszero(ret) { revert (0, 0) }

      // Check return value - if sender is not admin, revert
      if iszero(eq(sender, mload(add(0x40, ptr)))) { revert (0, 0) }
      // Check return value - if crowdsale is already initialized, revert
      if gt(mload(add(0x60, ptr)), 0) { revert (0, 0) }
      // Check return value - if token name is zero, revert
      if iszero(mload(add(0x80, ptr))) { revert (0, 0) }
    }

    // Allocate space for return storage request -
    store_data = new bytes32[](4);

    // First two slots are blank - this function does not accept eth
    // Store crowdsale initialization status
    store_data[2] = CROWDSALE_IS_INIT;
    store_data[3] = bytes32(1);
  }

  struct CrowdsaleFinalize {
    bytes4 rd_multi;
    bytes32 admin_storage;
    bytes32 crowdsale_init_status_storage;
    bytes32 crowdsale_finalized_status_storage;
  }

  /*
  Allows the crowdsale admin to finalize a crowdsale, provided it is fully initialized, and not already finalized

  @param _context: The execution context for this application - a 96-byte array containing (in order):
    1. Application execution id
    2. Original script sender (address, padded to 32 bytes)
    3. Wei amount sent with transaction to storage
  @return store_data: A formatted storage request - first 64 bytes designate a forwarding address (and amount) for any wei sent
  */
  function finalizeCrowdsale(bytes _context) public view returns (bytes32[] store_data) {
    // Ensure valid input
    if (_context.length != 96)
      triggerException(ERR_UNKNOWN_CONTEXT);

    // Get sender and exec id for this app instance
    address sender;
    bytes32 exec_id;
    (exec_id, sender, ) = parse(_context);

    // Place struct in memory to hold values
    CrowdsaleFinalize memory cr_fin = CrowdsaleFinalize({
      rd_multi: RD_MULTI,
      admin_storage: ADMIN,
      crowdsale_init_status_storage: CROWDSALE_IS_INIT,
      crowdsale_finalized_status_storage: CROWDSALE_IS_FINALIZED
    });

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x40)
      // Place function selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(cr_fin))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place admin address, crowdsale init status, crowdsale finalization status, and total token supply storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, cr_fin)))
      mstore(add(0x84, ptr), mload(add(0x40, cr_fin)))
      mstore(add(0xa4, ptr), mload(add(0x60, cr_fin)))
      // Read from storage, check return, and store value at pointer
      let ret := staticcall(gas, caller, ptr, 0xc4, ptr, 0xa0)
      if iszero(ret) { revert (0, 0) }

      // Check return value - if sender is not admin, revert
      if iszero(eq(sender, mload(add(0x40, ptr)))) { revert (0, 0) }
      // Check return value - if crowdsale not initialized - revert
      if iszero(mload(add(0x60, ptr))) { revert (0, 0) }
      // Check return value - if crowdsale is already finalized, revert
      if gt(mload(add(0x80, ptr)), 0) { revert (0, 0) }
    }

    // Allocate space for return storage request -
    store_data = new bytes32[](4);

    // First two slots are blank - this function does not accept eth
    // Store new crowdsale status
    store_data[2] = CROWDSALE_IS_FINALIZED;
    store_data[3] = bytes32(1);
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

  // Parses context array and returns execution id, sender address, and sent wei amount
  function parse(bytes _context) internal pure returns (bytes32 exec_id, address from, uint wei_sent) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
      wei_sent := mload(add(0x60, _context))
    }
    // Ensure sender and exec id are valid
    if (from == address(0) || exec_id == bytes32(0))
      triggerException(ERR_UNKNOWN_CONTEXT);
  }
}
