pragma solidity ^0.4.21;

library InitToken {

  /// TOKEN STORAGE ///

  // Storage location for token administrator address
  // Serves no purpose in this standard token contract, but can be used in other token contracts
  bytes32 public constant TOKEN_ADMIN = keccak256("token_admin");

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

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));


  /*
  Initializes a standard token application. Does not check for valid name, symbol, decimals, supply, or owner.

  @param _name: The plaintext token name to use
  @param _symbol: The plaintext token symbol to use
  @param _decimals: The number of display decimals used by the token
  @param _total_supply: The total number of tokens to create and award to the owner
  @param _owner: Token creator and admin address. Is awarded with the token's initial supply
  @return store_data: A formatted storage request - [location][data][location][data]...
  */
  function init(bytes32 _name, bytes32 _symbol, uint _decimals, uint _total_supply, address _owner) public pure
  returns (bytes32[] store_data) {
    // Allocate space for return value
    store_data = new bytes32[](12);

    // Store token name, symbol, and decimals
    store_data[0] = TOKEN_NAME;
    store_data[1] = _name;
    store_data[2] = TOKEN_SYMBOL;
    store_data[3] = _symbol;
    store_data[4] = TOKEN_DECIMALS;
    store_data[5] = bytes32(_decimals);

    // Store total supply, admin address, and initial owner balance
    store_data[6] = TOKEN_TOTAL_SUPPLY;
    store_data[7] = bytes32(_total_supply);
    store_data[8] = TOKEN_ADMIN;
    store_data[9] = bytes32(_owner);
    store_data[10] = keccak256(keccak256(_owner), TOKEN_BALANCES);
    store_data[11] = bytes32(_total_supply);
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
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Get owner balance location
    bytes32 balance_loc = keccak256(keccak256(_owner), TOKEN_BALANCES);

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and owner balance location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), balance_loc)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      owner_balance := mload(ptr)
    }
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
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Get spender allowed amount storage location
    bytes32 allowance_loc = keccak256(keccak256(_owner), TOKEN_ALLOWANCES);
    allowance_loc = keccak256(keccak256(_spender), allowance_loc);

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and owner balance location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), allowance_loc)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      allowed := mload(ptr)
    }
  }

  /*
  Returns the number of display decimals for a token

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_decimals: The number of decimals associated with token balances
  */
  function decimals(address _storage, bytes32 _exec_id) public view
  returns (uint token_decimals) {
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Place token decimals location in memory
    bytes32 decimals_storage = TOKEN_DECIMALS;

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and decimals storage location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), decimals_storage)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      token_decimals := mload(ptr)
    }
  }

  /*
  Returns the total token supply of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return total_supply: The total token supply
  */
  function totalSupply(address _storage, bytes32 _exec_id) public view
  returns (uint total_supply) {
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Place token totalsupply location in memory
    bytes32 total_supply_storage = TOKEN_TOTAL_SUPPLY;

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and total supply storage location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), total_supply_storage)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      total_supply := mload(ptr)
    }
  }

  /*
  Returns the name field of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_name: The name of the token
  */
  function name(address _storage, bytes32 _exec_id) public view returns (bytes32 token_name) {
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Place token name location in memory
    bytes32 name_storage = TOKEN_NAME;

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and name storage location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), name_storage)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      token_name := mload(ptr)
    }
  }

  /*
  Returns the ticker symbol of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_symbol: The token's ticker symbol
  */
  function symbol(address _storage, bytes32 _exec_id) public view returns (bytes32 token_symbol) {
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;

    // Place token ticker symbol location in memory
    bytes32 symbol_storage = TOKEN_SYMBOL;

    assembly {
      // Allocate calldata pointer and store read selector, exec id, and symbol storage location
      let ptr := mload(0x40)
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), symbol_storage)

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      token_symbol := mload(ptr)
    }
  }

  struct TokenInfo {
    bytes4 rd_multi;
    bytes32 name_storage;
    bytes32 symbol_storage;
    bytes32 decimals_storage;
    bytes32 total_supply_storage;
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

    // Create struct in memory to hold variables
    TokenInfo memory token_info = TokenInfo({
      rd_multi: RD_MULTI,
      name_storage: TOKEN_NAME,
      symbol_storage: TOKEN_SYMBOL,
      decimals_storage: TOKEN_DECIMALS,
      total_supply_storage: TOKEN_TOTAL_SUPPLY
    });

    assembly {
      // Allocate calldata pointer and store readMulti selector, exec id, data read offset and read size
      let ptr := mload(0x40)
      mstore(ptr, mload(token_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place token name, symbol, decimal, and total supply storage locatios in calldata
      mstore(add(0x64, ptr), mload(add(0x20, token_info)))
      mstore(add(0x84, ptr), mload(add(0x40, token_info)))
      mstore(add(0xa4, ptr), mload(add(0x60, token_info)))
      mstore(add(0xc4, ptr), mload(add(0x80, token_info)))

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0xe4, ptr, 0xc0)
      if iszero(ret) { revert (0, 0) }

      // Get return values
      token_name := mload(add(0x40, ptr))
      token_symbol := mload(add(0x60, ptr))
      token_decimals := mload(add(0x80, ptr))
      total_supply := mload(add(0xa0, ptr))
    }
  }
}
