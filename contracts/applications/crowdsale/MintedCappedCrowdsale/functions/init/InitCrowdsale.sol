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

  // Storage location for the amount of tokens still available for purchase in this crowdsale
  bytes32 public constant TOKENS_REMAINING = keccak256("crowdsale_tokens_remaining");

  // Storage location of token per wei rate
  bytes32 public constant SALE_RATE = keccak256("crowdsale_sale_rate");

  // Storage location of crowdsale start time
  bytes32 public constant CROWDSALE_STARTS_AT = keccak256("crowdsale_starts_at");

  // Storage location of crowdsale end time
  bytes32 public constant CROWDSALE_ENDS_AT = keccak256("crowdsale_ends_at");

  // Storage location for the number of tokens minted during the crowdsale
  bytes32 public constant TOTAL_TOKENS_MINTED = keccak256("crowdsale_tokens_minted");

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

  /// Storage location for an array of addresses with some form of reserved tokens
  bytes32 public constant TOKEN_RESERVED_DESTINATIONS = keccak256("token_reserved_dest_list");

  // Storage seed for reserved token information for a given address
  // Maps an address for which tokens are reserved to a struct:
  // ReservedInfo { uint destination_list_index; uint num_tokens; uint num_percent; uint percent_decimals; }
  // destination_list_index is the address's index in TOKEN_RESERVED_DESTINATIONS, plus 1. 0 means the address is not in the list
  bytes32 public constant TOKEN_RESERVED_ADDR_INFO = keccak256("token_reserved_addr_info");

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 public constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /*
  Creates a crowdsale with initial conditions. The sender (admin) should now initialize the crowdsale's token,
  and finalize the initialization of the crowdsale, or adjust variables first

  @param _wallet: The team funds wallet, where crowdsale purchases are forwarded
  @param _token_sell_cap: The maximum amount of tokens to sell during the crowdsale
  @param _sale_rate: The amount of tokens purchased per wei invested
  @param _start_time: The start time of the crowdsale
  @param _end_time: The end time of the crowdsale
  @param _admin: The address to set as crowdsale admin - is allowed to complete initialization of the crowdsale
  @return store_data: A formatted storage request
  */
  function init(address _wallet, uint _token_sell_cap, uint _sale_rate, uint _start_time, uint _end_time, address _admin) public view
  returns (bytes32[] store_data) {
    // Ensure valid input
    require(
      _wallet != address(0)
      && _token_sell_cap > 0
      && _sale_rate > 0
      && _start_time >= now
      && _end_time > _start_time
      && _admin != address(0)
    );

    // Construct storage request -
    store_data = new bytes32[](12);

    // Set admin, wallet, token sell cap, sale rate, and crowdsale start and end time values
    store_data[0] = ADMIN;
    store_data[1] = bytes32(_admin);
    store_data[2] = WALLET;
    store_data[3] = bytes32(_wallet);
    store_data[4] = TOKENS_REMAINING;
    store_data[5] = bytes32(_token_sell_cap);
    store_data[6] = SALE_RATE;
    store_data[7] = bytes32(_sale_rate);
    store_data[8] = CROWDSALE_STARTS_AT;
    store_data[9] = bytes32(_start_time);
    store_data[10] = CROWDSALE_ENDS_AT;
    store_data[11] = bytes32(_end_time);
  }

  /// CROWDSALE GETTERS ///

  /*
  Returns sale information on a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return sale_rate: The number of tokens recieved per wei spent
  @return start_time: The crowdsale's start time
  @return end_time: The crowdsale's end time
  */
  function getCrowdsaleInfo(address _storage, bytes32 _exec_id) public view returns (uint sale_rate, uint start_time, uint end_time) {
    // Place 'readMulti' selector in memory
    bytes4 rd_multi = RD_MULTI;

    // Get sale rate, start time, and end time storage locations
    bytes32 sale_rate_storage = SALE_RATE;
    bytes32 start_time_storage = CROWDSALE_STARTS_AT;
    bytes32 end_time_storage = CROWDSALE_ENDS_AT;

    assembly {
      // Get pointer to free memory for calldata
      let ptr := mload(0x40)
      // Store 'readMulti' selector, app exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 3)
      // Store crowdsale sale rate, start time, and end time storage locations in calldata
      mstore(add(0x64, ptr), sale_rate_storage)
      mstore(add(0x84, ptr), start_time_storage)
      mstore(add(0xa4, ptr), end_time_storage)
      // Read from storage, and store return in pointer
      let ret := staticcall(gas, _storage, ptr, 0xc4, ptr, 0xa0)
      if iszero(ret) { revert (0, 0) }

      // Get return values
      sale_rate := mload(add(0x40, ptr))
      start_time := mload(add(0x60, ptr))
      end_time := mload(add(0x80, ptr))
    }
  }

  struct CrowdsaleStatus {
    bytes4 rd_multi;
    bytes32 crowdsale_init_status_storage;
    bytes32 crowdsale_finalized_status_storage;
    bytes32 wei_raised_storage;
    bytes32 tokens_remaining_storage;
  }

  /*
  Returns crowdsale status

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return is_initialized: Whether the admin has finished crowdsale initialization
  @return is_finalized: Whether the crowdsale is still accepting purchases
  @return wei_raised: Total amount of wei raised so far
  @return tokens_remaining: The number of tokens still available for sale
  */
  function getCrowdsaleStatus(address _storage, bytes32 _exec_id) public view
  returns (bool is_initialized, bool is_finalized, uint wei_raised, uint tokens_remaining) {
    // Create struct in memory to hold values
    CrowdsaleStatus memory cd_stat = CrowdsaleStatus({
      rd_multi: RD_MULTI,
      crowdsale_init_status_storage: CROWDSALE_IS_INIT,
      crowdsale_finalized_status_storage: CROWDSALE_IS_FINALIZED,
      wei_raised_storage: WEI_RAISED,
      tokens_remaining_storage: TOKENS_REMAINING
    });

    assembly {
      // Get pointer to free memory for calldata
      let ptr := mload(0x40)
      // Store 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, mload(cd_stat))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place crowdsale status storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, cd_stat)))
      mstore(add(0x84, ptr), mload(add(0x40, cd_stat)))
      mstore(add(0xa4, ptr), mload(add(0x60, cd_stat)))
      mstore(add(0xc4, ptr), mload(add(0x80, cd_stat)))
      // Read from storage, and store return in pointer
      let ret := staticcall(gas, _storage, ptr, 0xe4, ptr, 0xc0)
      if iszero(ret) { revert (0, 0) }

      // Get returned values -
      is_initialized := mload(add(0x40, ptr))
      is_finalized := mload(add(0x60, ptr))
      wei_raised := mload(add(0x80, ptr))
      tokens_remaining := mload(add(0xa0, ptr))
    }
  }

  /*
  Returns the number of tokens sold so far this crowdsale, calculated from crowdsale sale rate and wei raised

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return tokens_sold: The number of tokens sold this crowdsale so far
  */
  function getTokensSold(address _storage, bytes32 _exec_id) public view
  returns (uint tokens_sold) {
    // Place 'readMulti' function selector in memory
    bytes4 rd_multi = RD_MULTI;

    // Get storage locations for token sale rate and wei raised
    bytes32 sale_rate_storage = SALE_RATE;
    bytes32 wei_raised_storage = WEI_RAISED;

    assembly {
      // Get pointer to free memory for calldata
      let ptr := mload(0x40)
      // Store 'readMulti' selector, exec id, data read offset, and read size in calldata
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place crowdsale sale rate and wei raised storage locations in calldata
      mstore(add(0x64, ptr), sale_rate_storage)
      mstore(add(0x84, ptr), wei_raised_storage)
      // Read from storage, and store return in pointer
      let ret := staticcall(gas, _storage, ptr, 0xa4, ptr, 0x80)
      if iszero(ret) { revert (0, 0) }

      // Get return value -
      tokens_sold := mul(mload(add(0x40, ptr)), mload(add(0x60, ptr)))
    }
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

  struct MintingInfo {
    bytes4 rd_multi;
    bytes32 total_tokens_minted_storage;
    bytes32 token_total_supply_storage;
  }

  /*
  Returns information on how many tokens hav been minted, and how many exist

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @return total_tokens_minted: The amount of tokens minted so far during the crowdsale
  @return token_total_supply: The total supply of the token
  */
  function getTokenMintingInfo(address _storage, bytes32 _exec_id) public view
  returns (uint total_tokens_minted, uint token_total_supply) {
    // Create struct in memory to hold values
    MintingInfo memory mint_info = MintingInfo({
      rd_multi: RD_MULTI,
      total_tokens_minted_storage: TOTAL_TOKENS_MINTED,
      token_total_supply_storage: TOKEN_TOTAL_SUPPLY
    });

    assembly {
      // Allocate calldata pointer and store readMulti selector, exec id, data read offset and read size
      let ptr := mload(0x40)
      mstore(ptr, mload(mint_info))
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 2)
      // Place total tokens minted and token total supply storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, mint_info)))
      mstore(add(0x84, ptr), mload(add(0x40, mint_info)))

      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0xa4, ptr, 0x80)
      if iszero(ret) { revert (0, 0) }

      // Get return values
      total_tokens_minted := mload(add(0x40, ptr))
      token_total_supply := mload(add(0x60, ptr))
    }
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
    // Place 'read' function selector in memory
    bytes4 rd_sing = RD_SING;
    // Get agent transfer agent status storage location
    bytes32 transfer_agent_status = keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS);

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x4)
      // Place 'read' selector, exec id, and transfer agent status storage location in calldata
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), transfer_agent_status)
      // Read from storage and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }

      // Get return value
      is_transfer_agent := mload(ptr)
    }
  }

  /*
  Returns information on a reserved token address (the crowdsale admin can set reserved tokens for addresses before initializing the crowdsale)

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @return reserved_destinations: A list of the addresses which have reserved tokens or percents
  */
  function getReservedTokenDestinationList(address _storage, bytes32 _exec_id) public view
  returns (uint num_destinations, address[] reserved_destinations) {
    // Place 'read' and 'readMulti' function selectors in memory
    bytes4 rd_sing = RD_SING;
    bytes4 rd_multi = RD_MULTI;
    // Get base storage location for reserved token destination list
    bytes32 reserved_destinations_storage = TOKEN_RESERVED_DESTINATIONS;

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x40)
      // Place 'read' fucntion selector, exec id, and reserved destination list location in calldata
      mstore(ptr, rd_sing)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), reserved_destinations_storage)
      // Read from storage, and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0x44, ptr, 0x20)
      if iszero(ret) { revert (0, 0) }
      // Get list length
      num_destinations := mload(ptr)

      // Loop through list in storage, and get each address -

      // Place 'readMulti' selector, exec id, data read offset, and read size in pointer
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), num_destinations)
      // Add each destination to calldata
      for { let offset := 0x00 } lt(offset, add(0x20, mul(0x20, num_destinations))) { offset := add(0x20, offset) } {
        mstore(add(add(0x64, offset), ptr), add(offset, reserved_destinations_storage))
      }
      // Read from storage
      ret := staticcall(gas, _storage, ptr, add(0x64, mul(0x20, num_destinations)), 0, 0)
      if iszero(ret) { revert (0, 0) }
      // Copy returned data to reserved_destinations
      reserved_destinations := add(0x20, msize)
      returndatacopy(reserved_destinations, 0x20, sub(returndatasize, 0x20))
    }
  }

  /*
  Returns information on a reserved token address (the crowdsale admin can set reserved tokens for addresses before initializing the crowdsale)

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @param _destination: The address about which reserved token information will be pulled
  @return destination_list_index: The index in the reserved token destination list where this address is found, plus 1. If zero, destination has no reserved tokens
  @return num_tokens: The number of tokens reserved for this address
  @return num_percent: The percent of tokens sold during the crowdsale reserved for this address
  @return percent_decimals: The number of decimals in the above percent reserved - used to calculate with precision
  */
  function getReservedDestinationInfo(address _storage, bytes32 _exec_id, address _destination) public view
  returns (uint destination_list_index, uint num_tokens, uint num_percent, uint percent_decimals ) {
    // Place 'readMulti' function selector in memory
    bytes4 rd_multi;
    // Get base storage location for destination reserved token info struct
    bytes32 destination_storage = keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO);

    assembly {
      // Get pointer for calldata
      let ptr := mload(0x40)
      // Place selector, exec id, data read offset, and read size in pointer
      mstore(ptr, rd_multi)
      mstore(add(0x04, ptr), _exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place storage locations at pointer
      mstore(add(0x64, ptr), destination_storage)
      mstore(add(0x84, ptr), add(0x20, destination_storage))
      mstore(add(0xa4, ptr), add(0x40, destination_storage))
      mstore(add(0xc4, ptr), add(0x60, destination_storage))
      // Read from storage and store return at pointer
      let ret := staticcall(gas, _storage, ptr, 0xe4, ptr, 0xc0)
      if iszero(ret) { revert (0, 0) }
      // Get return values
      destination_list_index := mload(add(0x40, ptr))
      num_tokens := mload(add(0x60, ptr))
      num_percent := mload(add(0x80, ptr))
      percent_decimals := mload(add(0xa0, ptr))
    }
  }
}
