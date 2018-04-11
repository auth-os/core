pragma solidity ^0.4.21;

library InitCrowdsale {

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 public constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the sale is ready to run
  bytes32 public constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 public constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the crowdsale's start time
  bytes32 public constant CROWDSALE_START_TIME = keccak256("crowdsale_start_time");

  // Storage location of the amount of time the crowdsale will take, accounting for all tiers
  bytes32 public constant CROWDSALE_TOTAL_DURATION = keccak256("crowdsale_total_duration");

  // Storage location of the amount of tokens sold in the crowdsale so far. Does not include reserved tokens
  bytes32 public constant CROWDSALE_TOKENS_SOLD = keccak256("crowdsale_tokens_sold");

  // Storage location of the minimum amount of wei allowed to be contributed for each purchase
  bytes32 public constant CROWDSALE_MINIMUM_CONTRIBUTION = keccak256("crowdsale_min_cap");

  // Maps addresses to a boolean indicating whether or not this address has contributed
  // At its base location, stores the amount of unique contributors so far in this crowdsale
  bytes32 public constant CROWDSALE_UNIQUE_CONTRIBUTORS = keccak256("crowdsale_contributors");

  // Storage location of a list of the tiers the crowdsale will have
  /* Each tier mimics the following struct:
  struct CrowdsaleTier {
    bytes32 _tier_name;                 // The name of the crowdsale tier
    uint _tier_token_sell_cap;          // The maximum number of tokens that will be sold during this tier
    uint _tier_purchase_price;          // The price of a token in wei for this tier
    uint _duration;                     // The amount of time this tier will be active for
    bool _tier_duration_is_modifiable;  // Whether the crowdsale admin is allowed to modify the duration of a tier before it goes live
    bool _tier_is_whitelist_enabled     // Whether this tier of the crowdsale requires users to be on a purchase whitelist
  }
  */
  bytes32 public constant CROWDSALE_TIERS = keccak256("crowdsale_tier_list");

  // Storage location of the CROWDSALE_TIERS index (-1) of the current tier. If zero, no tier is currently active
  bytes32 public constant CROWDSALE_CURRENT_TIER = keccak256("crowdsale_current_tier");

  // Storage location of the end time of the current tier. Purchase attempts beyond this time will update the current tier (if another is available)
  bytes32 public constant CURRENT_TIER_ENDS_AT = keccak256("crowdsale_tier_ends_at");

  // Storage location of the total number of tokens remaining for purchase in the current tier
  bytes32 public constant CURRENT_TIER_TOKENS_REMAINING = keccak256("crowdsale_tier_tokens_remaining");

  // Storage location of team funds wallet
  bytes32 public constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 public constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage seed for crowdsale whitelist mappings - maps each tier's index to a mapping of addresses to whtielist information
  /* Each whitelist entry mimics this struct:
  struct WhitelistListing {
    uint minimum_contribution;
    uint max_contribution;
  }
  */
  bytes32 public constant SALE_WHITELIST = keccak256("crowdsale_purchase_whitelist");

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

  /// EXCEPTION MESSAGES ///

  bytes32 public constant ERR_IMPROPER_INITIALIZATION = bytes32("ImproperInitialization"); // Initialization variables invalid
  bytes32 public constant ERR_READ_FAILED = bytes32("StorageReadFailed"); // Read from storage address failed

  /*
  Creates a crowdsale with initial conditions. The admin should now initialize the crowdsale's token, as well
  as any additional tiers of the crowdsale that will exist, followed by finalizing the initialization of the crowdsale.

  @param _team_wallet: The team funds wallet, where crowdsale purchases are forwarded
  @param _start_time: The start time of the initial tier of the crowdsale
  @param _initial_tier_name: The name of the initial tier of the crowdsale
  @param _initial_tier_price: The price of each token purchased in wei, for the initial crowdsale tier
  @param _initial_tier_duration: The duration of the initial tier of the crowdsale
  @param _initial_tier_token_sell_cap: The maximum number of tokens that can be sold during the initial tier
  @param _initial_tier_is_whitelisted: Whether the initial tier of the crowdsale requires an address be whitelisted for successful purchase
  @param _admin: A privileged address which is able to complete the crowdsale initialization process
  @return store_data: A formatted storage request
  */
  function init(
    address _team_wallet,
    uint _start_time,
    bytes32 _initial_tier_name,
    uint _initial_tier_price,
    uint _initial_tier_duration,
    uint _initial_tier_token_sell_cap,
    bool _initial_tier_is_whitelisted,
    address _admin
  ) public view returns (bytes32[] store_data) {
    // Ensure valid input
    if (
      _team_wallet == address(0)
      || _initial_tier_price == 0
      || _start_time < now
      || _start_time + _initial_tier_duration <= _start_time
      || _initial_tier_token_sell_cap == 0
      || _admin == address(0)
    ) triggerException(ERR_IMPROPER_INITIALIZATION);

    // Create storage data return buffer in memory
    uint ptr = stBuff();
    // Push payment information (init takes no payment)
    stPush(ptr, 0);
    stPush(ptr, 0);
    // Push admin address, team wallet, crowdsale overall duration, and overall crowdsale start time
    stPush(ptr, ADMIN);
    stPush(ptr, bytes32(_admin));
    stPush(ptr, WALLET);
    stPush(ptr, bytes32(_team_wallet));
    stPush(ptr, CROWDSALE_TOTAL_DURATION);
    stPush(ptr, bytes32(_initial_tier_duration));
    stPush(ptr, CROWDSALE_START_TIME);
    stPush(ptr, bytes32(_start_time));

    // Push initial crowdsale tiers list length (1), and initial tier information to list
    stPush(ptr, CROWDSALE_TIERS);
    stPush(ptr, bytes32(1));
    // Tier name
    stPush(ptr, bytes32(32 + uint(CROWDSALE_TIERS)));
    stPush(ptr, _initial_tier_name);
    // Tier token sell cap
    stPush(ptr, bytes32(64 + uint(CROWDSALE_TIERS)));
    stPush(ptr, bytes32(_initial_tier_token_sell_cap));
    // Tier purchase price
    stPush(ptr, bytes32(96 + uint(CROWDSALE_TIERS)));
    stPush(ptr, bytes32(_initial_tier_price));
    // Tier active duration
    stPush(ptr, bytes32(128 + uint(CROWDSALE_TIERS)));
    stPush(ptr, bytes32(_initial_tier_duration));
    // Whether this tier's duration is modifiable prior to its start time (automatically true for initial tiers)
    stPush(ptr, bytes32(160 + uint(CROWDSALE_TIERS)));
    stPush(ptr, bytes32(1));
    // Whether this tier requires an address be whitelisted to complete token purchase
    stPush(ptr, bytes32(192 + uint(CROWDSALE_TIERS)));
    stPush(ptr, (_initial_tier_is_whitelisted ? bytes32(1) : bytes32(0)));

    // Push current crowdsale tier to buffer (initial tier is '1' - index is 0, but offset by 1 in storage)
    stPush(ptr, CROWDSALE_CURRENT_TIER);
    stPush(ptr, bytes32(1));
    // Push end time of initial tier to buffer
    stPush(ptr, CURRENT_TIER_ENDS_AT);
    stPush(ptr, bytes32(_initial_tier_duration + _start_time));
    // Push number of tokens remaining to be sold in the initial tier to the buffer
    stPush(ptr, CURRENT_TIER_TOKENS_REMAINING);
    stPush(ptr, bytes32(_initial_tier_token_sell_cap));

    // Get bytes32[] storage request array from buffer
    store_data = getBuffer(ptr);
  }

  /*
  Returns the address of the admin of the crowdsale

  @param _storage: The application's storage address
  @param _exec_id: The execution id to pull the admin address from
  @return admin: The address of the admin of the crowdsale
  */
  function getAdmin(address _storage, bytes32 _exec_id) public view returns (address admin) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and admin address storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, ADMIN);

    // Read from storage and get return value
    admin = address(readSingleFrom(ptr, _storage));
  }

  /// CROWDSALE GETTERS ///

  /*
  Returns sale information on a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return wei_raised: The amount of wei raised in the crowdsale so far
  @return team_wallet: The address to which funds are forwarded during this crowdsale
  @return minimum_contribution: The minimum amount of wei that must be sent with each purchase
  @return is_initialized: Whether or not the crowdsale has been completely initialized by the admin
  @return is_finalized: Whether or not the crowdsale has been completely finalized by the admin
  */
  function getCrowdsaleInfo(address _storage, bytes32 _exec_id) public view
  returns (uint wei_raised, address team_wallet, uint minimum_contribution, bool is_initialized, bool is_finalized) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(5));
    // Push wei raised, team wallet, and minimum contribution amount storage locations to calldata buffer
    cdPush(ptr, WEI_RAISED);
    cdPush(ptr, WALLET);
    cdPush(ptr, CROWDSALE_MINIMUM_CONTRIBUTION);
    // Push crowdsale initialization and finalization status storage locations to buffer
    cdPush(ptr, CROWDSALE_IS_INIT);
    cdPush(ptr, CROWDSALE_IS_FINALIZED);
    // Read from storage, and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get returned data -
    wei_raised = uint(read_values[0]);
    team_wallet = address(read_values[1]);
    minimum_contribution = uint(read_values[2]);
    is_initialized = (read_values[3] == bytes32(0) ? false : true);
    is_finalized = (read_values[4] == bytes32(0) ? false : true);
  }

  /*
  Returns the number of unique contributors to a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return num_unique: The number of unique contributors in a crowdsale so far
  */
  function getCrowdsaleUniqueBuyers(address _storage, bytes32 _exec_id) public view returns (uint num_unique) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and unique contributor storage location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, CROWDSALE_UNIQUE_CONTRIBUTORS);
    // Read from storage and return
    num_unique = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns the start and end time of the crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return start_time: The start time of the first tier of a crowdsale
  @return end_time: The time at which the crowdsale ends
  */
  function getCrowdsaleStartAndEndTimes(address _storage, bytes32 _exec_id) public view returns (uint start_time, uint end_time) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, read size, start time, and total duration locations to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(2));
    cdPush(ptr, CROWDSALE_START_TIME);
    cdPush(ptr, CROWDSALE_TOTAL_DURATION);
    // Read from storage
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);
    // Get return values
    start_time = read_values[0];
    end_time = start_time + read_values[1];
  }

  /*
  Returns information on the current crowdsale tier

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return tier_name: The name of the current tier
  @return tier_index: The current tier's index in the CROWDSALE_TIERS list
  @return tier_ends_at: The time at which purcahses for the current tier are forcibly locked
  @return tier_tokens_remaining: The amount of tokens remaining to be purchased in the current tier
  @return tier_price: The price of each token purchased this tier, in wei
  @return duration_is_modifiable: Whether the crowdsale admin can update the duration of this tier before it starts
  @return whitelist_enabled: Whether an address must be whitelisted to participate in this tier
  */
  function getCurrentTierInfo(address _storage, bytes32 _exec_id) public view
  returns (bytes32 tier_name, uint tier_index, uint tier_ends_at, uint tier_tokens_remaining, uint tier_price, bool duration_is_modifiable, bool whitelist_enabled) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(3));
    // Push current tier expiration time, current tier index, and current tier tokens remaining storage locations to calldata buffer
    cdPush(ptr, CURRENT_TIER_ENDS_AT);
    cdPush(ptr, CROWDSALE_CURRENT_TIER);
    cdPush(ptr, CURRENT_TIER_TOKENS_REMAINING);
    // Read from storage and store return in buffer
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);

    // If the returned index was 0, current tier does not exist: return now
    if (read_values[1] == 0)
      return;

    // Get returned values -
    tier_ends_at = read_values[0];
    // Indices are stored as 1 + (actual index), to avoid conflicts with a default 0 value
    tier_index = read_values[1] - 1;
    tier_tokens_remaining = read_values[2];

    // Overwrite previous buffer, and create new 'readMulti' calldata buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(4));
    // Push tier name, tier token price, modifiable status, and tier whitelist status storage locations to buffer
    uint name_storage_offset = 32 + (192 * tier_index) + uint(CROWDSALE_TIERS);
    cdPush(ptr, bytes32(name_storage_offset)); // Tier name
    cdPush(ptr, bytes32(64 + name_storage_offset)); // Tier purchase price
    cdPush(ptr, bytes32(128 + name_storage_offset)); // Tier modifiability status
    cdPush(ptr, bytes32(160 + name_storage_offset)); // Tier whitelist status
    // Read from storage and get return values
    read_values = readMultiUintFrom(ptr, _storage);
    tier_name = bytes32(read_values[0]);
    tier_price = read_values[1];
    duration_is_modifiable = (read_values[2] == 0 ? false : true);
    whitelist_enabled = (read_values[3] == 0 ? false : true);
  }

  /*
  Returns information on a given tier

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _index: The index of the tier in the crowdsale tier list. Input index should be like a normal array index (lowest index: 0)
  @return tier_name: The name of the returned tier
  @return tier_sell_cap: The amount of tokens designated to be sold during this tier
  @return tier_price: The price of each token in wei for this tier
  @return tier_duration: The duration of the given tier
  @return duration_is_modifiable: Whether the crowdsale admin can change the duration of this tier prior to its start time
  @return whitelist_enabled: Whether an address must be whitelisted to participate in this tier
  */
  function getCrowdsaleTier(address _storage, bytes32 _exec_id, uint _index) public view
  returns (bytes32 tier_name, uint tier_sell_cap, uint tier_price, uint tier_duration, bool duration_is_modifiable, bool whitelist_enabled) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(6));
    // Get tier offset storage location
    uint tier_info_location = 32 + (192 * _index) + uint(CROWDSALE_TIERS);
    // Push tier name, sell cap, duration, and modifiable status storage locations to buffer
    cdPush(ptr, bytes32(tier_info_location)); // Name
    cdPush(ptr, bytes32(32 + tier_info_location)); // Token sell cap
    cdPush(ptr, bytes32(64 + tier_info_location)); // Tier purchase price
    cdPush(ptr, bytes32(96 + tier_info_location)); // Tier duration
    cdPush(ptr, bytes32(128 + tier_info_location)); // Modifiability status
    cdPush(ptr, bytes32(160 + tier_info_location)); // Whitelist enabled status
    // Read from storage and store return in buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);

    // Get returned values -
    tier_name = read_values[0];
    tier_sell_cap = uint(read_values[1]);
    tier_price = uint(read_values[2]);
    tier_duration = uint(read_values[3]);
    duration_is_modifiable = (read_values[4] == bytes32(0) ? false : true);
    whitelist_enabled = (read_values[5] == bytes32(0) ? false : true);
  }

  /*
  Returns the maximum amount of wei to raise, as well as the total amount of tokens that can be sold

  @param _storage: The storage address of the crowdsale application
  @param _exec_id: The execution id of the application
  @return wei_raise_cap: The maximum amount of wei to raise
  @return total_sell_cap: The maximum amount of tokens to sell
  */
  function getCrowdsaleMaxRaise(address _storage, bytes32 _exec_id) public view returns (uint wei_raise_cap, uint total_sell_cap) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and tier list length location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, CROWDSALE_TIERS);
    // Read from storage
    uint num_tiers = uint(readSingleFrom(ptr, _storage));

    // Overwrite previous buffer - push exec id, data read offset, and read size to buffer
    cdOverwrite(ptr, RD_MULTI);
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(2 * num_tiers));
    // Loop through tiers and get sell cap and purchase price for each tier
    for (uint i = 0; i < num_tiers; i++) {
      cdPush(ptr, bytes32(64 + (192 * i) + uint(CROWDSALE_TIERS))); // token sell cap
      cdPush(ptr, bytes32(96 + (192 * i) + uint(CROWDSALE_TIERS))); // tier purchase price
    }

    // Read from storage
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);
    // Loop through and get wei raise cap and token sell cap
    for (i = 0; i < read_values.length; i+=2) {
      total_sell_cap += read_values[i];
      // Increase maximum wei to raise by tier token sell cap * tier purchase price
      wei_raise_cap += (read_values[i] * read_values[i + 1]);
    }
  }

  /*
  Returns a list of the named tiers of the crowdsale

  @param _storage: The storage address of the crowdsale application
  @param _exec_id: The execution id of the application
  @return crowdsale_tiers: A list of each tier of the crowdsale
  */
  function getCrowdsaleTierList(address _storage, bytes32 _exec_id) public view returns (bytes32[] memory crowdsale_tiers) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and crowdsale tier list length location to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, CROWDSALE_TIERS);
    // Read from storage and get list length
    uint list_length = uint(readSingleFrom(ptr, _storage));

    // Overwrite previous buffer, and create 'readMulti' calldata buffer
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(list_length));
    // Loop over each tier name list location and add to buffer
    for (uint i = 0; i < list_length; i++)
      cdPush(ptr, bytes32(32 + (192 * i) + uint(CROWDSALE_TIERS)));

    // Read from storage and return
    crowdsale_tiers = readMultiFrom(ptr, _storage);
  }

  /*
  Loops through all tiers and their durations, and returns the passed-in index's start and end dates

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _index: The index of the tier in the crowdsale tier list. Input index should be like a normal array index (lowest index: 0)
  @return tier_start: The time when the given tier starts
  @return tier_end: The time at which the given tier ends
  */
  function getTierStartAndEndDates(address _storage, bytes32 _exec_id, uint _index) public view returns (uint tier_start, uint tier_end) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(3 + _index));
    // Add crowdsale tier list length and crowdsale start time to buffer
    cdPush(ptr, CROWDSALE_TIERS);
    cdPush(ptr, CROWDSALE_START_TIME);
    // Get storage read offset for initial tier duration, then loop over each tier until _index and add their duration storage locations to the read buffer
    bytes32 duration_offset = bytes32(128 + uint(CROWDSALE_TIERS));
    for (uint i = 0; i <= _index; i++) {
      cdPush(ptr, duration_offset);
      // Increment the duration offset to the next index in the array
      duration_offset = bytes32(192 + uint(duration_offset));
    }
    // Read from storage and store return in buffer
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);

    // Check that the passed-in index is within the range of the tier list
    if (read_values[0] <= _index)
      return (0, 0);

    // Get returned start time, then loop through each returned duration and get the start time for the tier
    tier_start = read_values[1];
    for (i = 0; i < _index; i++)
      tier_start += read_values[2 + i];

    // Get the tier end time - start time plus the duration of the tier, the last read value in the list
    tier_end = tier_start + read_values[read_values.length - 1];
  }

  /*
  Returns the number of tokens sold so far this crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return tokens_sold: The number of tokens sold this crowdsale so far
  */
  function getTokensSold(address _storage, bytes32 _exec_id) public view
  returns (uint tokens_sold) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id to buffer
    cdPush(ptr, _exec_id);
    // Push crowdsale total tokens sold location to buffer
    cdPush(ptr, CROWDSALE_TOKENS_SOLD);
    // Read from storage and return
    tokens_sold = uint(readSingleFrom(ptr, _storage));
  }

  /*
  Returns whitelist information for a given buyer

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _tier_index: The index of the tier about which the whitelist information will be pulled
  @param _buyer: The address of the user whose whitelist status will be returned
  @return minimum_contribution: The minimum ammount of wei this address must sent with each purchase
  @return max_spend_remaining: The maximum amount of wei able to be spent
  */
  function getWhitelistStatus(address _storage, bytes32 _exec_id, uint _tier_index, address _buyer) public view
  returns (uint minimum_contribution, uint max_spend_remaining) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(2));
    // Get buyer whitelist location for the tier -
    bytes32 location = keccak256(keccak256(_buyer), keccak256(_tier_index, SALE_WHITELIST));
    // Push whitelist minimum contribution location to buffer
    cdPush(ptr, location);
    // Push whitlist maximum spend amount remaining location to buffer
    cdPush(ptr, bytes32(32 + uint(location)));

    // Read from storage and return
    uint[] memory read_values = readMultiUintFrom(ptr, _storage);
    minimum_contribution = read_values[0];
    max_spend_remaining = read_values[1];
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
  Returns information on a reserved token address (the crowdsale admin can set reserved tokens for addresses before initializing the crowdsale)

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @return reserved_destinations: A list of the addresses which have reserved tokens or percents
  */
  function getReservedTokenDestinationList(address _storage, bytes32 _exec_id) public view
  returns (uint num_destinations, address[] reserved_destinations) {
    // Create 'read' calldata buffer in memory
    uint ptr = cdBuff(RD_SING);
    // Push exec id and reserved token destination list location to calldata buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, TOKEN_RESERVED_DESTINATIONS);
    // Read reserved destination list length from storage
    num_destinations = uint(readSingleFrom(ptr, _storage));

    /// Loop through each list in storage, and get each address -

    // Overwrite previous buffer with new 'readMulti' calldata buffer -
    cdOverwrite(ptr, RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(num_destinations));
    // Add each destination index location to calldata
    for (uint i = 1; i <= num_destinations; i++)
      cdPush(ptr, bytes32((32 * i) + uint(TOKEN_RESERVED_DESTINATIONS)));

    // Read from storage, and return data to buffer
    reserved_destinations = readMultiAddressFrom(ptr, _storage);
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
    // Create 'readMulti' calldata buffer in memory
    uint ptr = cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    cdPush(ptr, _exec_id);
    cdPush(ptr, 0x40);
    cdPush(ptr, bytes32(4));
    // Push reserved destination information storage locations to buffer -
    uint base_loc = uint(keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO));
    cdPush(ptr, bytes32(base_loc));
    cdPush(ptr, bytes32(32 + base_loc));
    cdPush(ptr, bytes32(64 + base_loc));
    cdPush(ptr, bytes32(96 + base_loc));

    // Read from storage, and return data to buffer
    bytes32[] memory read_values = readMultiFrom(ptr, _storage);
    // Get returned values -
    destination_list_index = uint(read_values[0]);
    // If the returned list index for the destination is 0, destination is not in list
    if (destination_list_index == 0)
      return;
    destination_list_index--;
    num_tokens = uint(read_values[1]);
    num_percent = uint(read_values[2]);
    percent_decimals = uint(read_values[3]);
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
  Creates a new calldata buffer at the pointer with the given selector. Does not update free memory

  @param _ptr: A pointer to the buffer to overwrite - will be the pointer to the new buffer as well
  @param _selector: The function selector to place in the buffer
  */
  function cdOverwrite(uint _ptr, bytes4 _selector) internal pure {
    assembly {
      // Store initial length of buffer - 4 bytes
      mstore(_ptr, 0x04)
      // Store function selector after length
      mstore(add(0x20, _ptr), _selector)
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
  function readMultiAddressFrom(uint _ptr, address _storage) internal view returns (address[] read_values) {
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
