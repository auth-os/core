pragma solidity ^0.4.23;

import "../../../../../lib/ReadFromBuffers.sol";
import "../../../../../lib/ArrayUtils.sol";

library InitCrowdsale {

  using ReadFromBuffers for uint;
  using ArrayUtils for bytes32[];
  using Exceptions for bytes32;

  /// CROWDSALE STORAGE ///

  // Storage location of crowdsale admin address
  bytes32 internal constant ADMIN = keccak256("admin");

  // Whether the crowdsale and token are initialized, and the sale is ready to run
  bytes32 internal constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the crowdsale's start time
  bytes32 internal constant CROWDSALE_START_TIME = keccak256("crowdsale_start_time");

  // Storage location of the amount of time the crowdsale will take, accounting for all tiers
  bytes32 internal constant CROWDSALE_TOTAL_DURATION = keccak256("crowdsale_total_duration");

  // Storage location of the amount of tokens sold in the crowdsale so far. Does not include reserved tokens
  bytes32 internal constant CROWDSALE_TOKENS_SOLD = keccak256("crowdsale_tokens_sold");

  // Storage location of the minimum amount of tokens allowed to be purchased
  bytes32 internal constant CROWDSALE_MINIMUM_CONTRIBUTION = keccak256("crowdsale_min_cap");

  // Maps addresses to a boolean indicating whether or not this address has contributed
  // At its base location, stores the amount of unique contributors so far in this crowdsale
  bytes32 internal constant CROWDSALE_UNIQUE_CONTRIBUTORS = keccak256("crowdsale_contributors");

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
  bytes32 internal constant CROWDSALE_TIERS = keccak256("crowdsale_tier_list");

  // Storage location of the CROWDSALE_TIERS index (-1) of the current tier. If zero, no tier is currently active
  bytes32 internal constant CROWDSALE_CURRENT_TIER = keccak256("crowdsale_current_tier");

  // Storage location of the end time of the current tier. Purchase attempts beyond this time will update the current tier (if another is available)
  bytes32 internal constant CURRENT_TIER_ENDS_AT = keccak256("crowdsale_tier_ends_at");

  // Storage location of the total number of tokens remaining for purchase in the current tier
  bytes32 internal constant CURRENT_TIER_TOKENS_REMAINING = keccak256("crowdsale_tier_tokens_remaining");

  // Storage location of team funds wallet
  bytes32 internal constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 internal constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Storage seed for crowdsale whitelist mappings - maps each tier's index to a mapping of addresses to whtielist information
  /* Each whitelist entry mimics this struct:
  struct WhitelistListing {
    uint minimum_contribution;
    uint max_contribution;
  }
  */
  bytes32 internal constant SALE_WHITELIST = keccak256("crowdsale_purchase_whitelist");

  /// TOKEN STORAGE ///

  // Storage location for token name
  bytes32 internal constant TOKEN_NAME = keccak256("token_name");

  // Storage location for token ticker symbol
  bytes32 internal constant TOKEN_SYMBOL = keccak256("token_symbol");

  // Storage location for token decimals
  bytes32 internal constant TOKEN_DECIMALS = keccak256("token_decimals");

  // Storage location for token totalSupply
  bytes32 internal constant TOKEN_TOTAL_SUPPLY = keccak256("token_total_supply");

  // Storage seed for user balances mapping
  bytes32 internal constant TOKEN_BALANCES = keccak256("token_balances");

  // Storage seed for user allowances mapping
  bytes32 internal constant TOKEN_ALLOWANCES = keccak256("token_allowances");

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
  Creates a crowdsale with initial conditions. The admin should now initialize the crowdsale's token, as well
  as any additional tiers of the crowdsale that will exist, followed by finalizing the initialization of the crowdsale.

  @param _team_wallet: The team funds wallet, where crowdsale purchases are forwarded
  @param _start_time: The start time of the initial tier of the crowdsale
  @param _initial_tier_name: The name of the initial tier of the crowdsale
  @param _initial_tier_price: The price of each token purchased in wei, for the initial crowdsale tier
  @param _initial_tier_duration: The duration of the initial tier of the crowdsale
  @param _initial_tier_token_sell_cap: The maximum number of tokens that can be sold during the initial tier
  @param _initial_tier_is_whitelisted: Whether the initial tier of the crowdsale requires an address be whitelisted for successful purchase
  @param _initial_tier_duration_is_modifiable: Whether the initial tier of the crowdsale has a modifiable duration
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
    bool _initial_tier_duration_is_modifiable,
    address _admin
  ) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (
      _team_wallet == address(0)
      || _initial_tier_price == 0
      || _start_time < now
      || _start_time + _initial_tier_duration <= _start_time
      || _initial_tier_token_sell_cap == 0
      || _admin == address(0)
    ) bytes32("ImproperInitialization").trigger();

    // Create storage data return buffer in memory
    uint ptr = ReadFromBuffers.stBuff(0, 0);
    // Push admin address, team wallet, crowdsale overall duration, and overall crowdsale start time
    ptr.stPush(ADMIN, bytes32(_admin));
    ptr.stPush(WALLET, bytes32(_team_wallet));
    ptr.stPush(CROWDSALE_TOTAL_DURATION, bytes32(_initial_tier_duration));
    ptr.stPush(CROWDSALE_START_TIME, bytes32(_start_time));
    // Push initial crowdsale tiers list length (1), and initial tier information to list
    ptr.stPush(CROWDSALE_TIERS, bytes32(1));
    // Tier name
    ptr.stPush(bytes32(32 + uint(CROWDSALE_TIERS)), _initial_tier_name);
    // Tier token sell cap
    ptr.stPush(bytes32(64 + uint(CROWDSALE_TIERS)), bytes32(_initial_tier_token_sell_cap));
    // Tier purchase price
    ptr.stPush(bytes32(96 + uint(CROWDSALE_TIERS)), bytes32(_initial_tier_price));
    // Tier active duration
    ptr.stPush(bytes32(128 + uint(CROWDSALE_TIERS)), bytes32(_initial_tier_duration));
    // Whether this tier's duration is modifiable prior to its start time
    ptr.stPush(bytes32(160 + uint(CROWDSALE_TIERS)), _initial_tier_duration_is_modifiable ? bytes32(1) : bytes32(0));
    // Whether this tier requires an address be whitelisted to complete token purchase
    ptr.stPush(bytes32(192 + uint(CROWDSALE_TIERS)), _initial_tier_is_whitelisted ? bytes32(1) : bytes32(0));

    // Push current crowdsale tier to buffer (initial tier is '1' - index is 0, but offset by 1 in storage)
    ptr.stPush(CROWDSALE_CURRENT_TIER, bytes32(1));
    // Push end time of initial tier to buffer
    ptr.stPush(CURRENT_TIER_ENDS_AT, bytes32(_initial_tier_duration + _start_time));
    // Push number of tokens remaining to be sold in the initial tier to the buffer
    ptr.stPush(CURRENT_TIER_TOKENS_REMAINING, bytes32(_initial_tier_token_sell_cap));

    // Get bytes32[] storage request array from buffer
    store_data = ptr.getBuffer();
  }

  /*
  Returns the address of the admin of the crowdsale

  @param _storage: The application's storage address
  @param _exec_id: The execution id to pull the admin address from
  @return admin: The address of the admin of the crowdsale
  */
  function getAdmin(address _storage, bytes32 _exec_id) public view returns (address admin) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and admin address storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(ADMIN);

    // Read from storage and get return value
    admin = address(ptr.readSingleFrom(_storage));
  }

  /// CROWDSALE GETTERS ///

  /*
  Returns sale information on a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return wei_raised: The amount of wei raised in the crowdsale so far
  @return team_wallet: The address to which funds are forwarded during this crowdsale
  @return minimum_contribution: The minimum amount of tokens that must be purchased
  @return is_initialized: Whether or not the crowdsale has been completely initialized by the admin
  @return is_finalized: Whether or not the crowdsale has been completely finalized by the admin
  */
  function getCrowdsaleInfo(address _storage, bytes32 _exec_id) public view
  returns (uint wei_raised, address team_wallet, uint minimum_contribution, bool is_initialized, bool is_finalized) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(5));
    // Push wei raised, team wallet, and minimum contribution amount storage locations to calldata buffer
    ptr.cdPush(WEI_RAISED);
    ptr.cdPush(WALLET);
    ptr.cdPush(CROWDSALE_MINIMUM_CONTRIBUTION);
    // Push crowdsale initialization and finalization status storage locations to buffer
    ptr.cdPush(CROWDSALE_IS_INIT);
    ptr.cdPush(CROWDSALE_IS_FINALIZED);
    // Read from storage, and store return in buffer
    bytes32[] memory read_values = ptr.readMultiFrom(_storage);
    // Ensure correct return length
    assert(read_values.length == 5);

    // Get returned data -
    wei_raised = uint(read_values[0]);
    team_wallet = address(read_values[1]);
    minimum_contribution = uint(read_values[2]);
    is_initialized = (read_values[3] == 0 ? false : true);
    is_finalized = (read_values[4] == 0 ? false : true);
  }

  /*
  Returns true if all tiers have been completely sold out

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return is_crowdsale_full: Whether or not the total number of tokens to sell in the crowdsale has been reached
  @return max_sellable: The total number of tokens that can be sold in the crowdsale
  */
  function isCrowdsaleFull(address _storage, bytes32 _exec_id) public view returns (bool is_crowdsale_full, uint max_sellable) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    // Push crowdsale tier list length and total tokens sold storage locations to buffer
    ptr.cdPush(CROWDSALE_TIERS);
    ptr.cdPush(CROWDSALE_TOKENS_SOLD);
    // Read from storage
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2);

    // Get number of tiers and tokens sold
    uint num_tiers = read_values[0];
    uint tokens_sold = read_values[1];

    // Overwrite previous buffer and create new calldata buffer
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_tiers));
    // Loop through tier cap locations, and add each to the calldata buffer
    for (uint i = 0; i < num_tiers; i++)
      ptr.cdPush(bytes32(64 + (192 * i) + uint(CROWDSALE_TIERS)));

    // Read from storage
    read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == num_tiers);

    // Loop through returned values, and get the sum of all tier token sell caps
    for (i = 0; i < read_values.length; i++)
      max_sellable += read_values[i];

    // Get return value
    is_crowdsale_full = (tokens_sold >= max_sellable ? true : false);
  }

  /*
  Returns the number of unique contributors to a crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return num_unique: The number of unique contributors in a crowdsale so far
  */
  function getCrowdsaleUniqueBuyers(address _storage, bytes32 _exec_id) public view returns (uint num_unique) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and unique contributor storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(CROWDSALE_UNIQUE_CONTRIBUTORS);
    // Read from storage and return
    num_unique = uint(ptr.readSingleFrom(_storage));
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
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, read size, start time, and total duration locations to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    ptr.cdPush(CROWDSALE_START_TIME);
    ptr.cdPush(CROWDSALE_TOTAL_DURATION);
    // Read from storage
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2);

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
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(3));
    // Push current tier expiration time, current tier index, and current tier tokens remaining storage locations to calldata buffer
    ptr.cdPush(CURRENT_TIER_ENDS_AT);
    ptr.cdPush(CROWDSALE_CURRENT_TIER);
    ptr.cdPush(CURRENT_TIER_TOKENS_REMAINING);
    // Read from storage and store return in buffer
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 3);

    // If the returned index was 0, current tier does not exist: return now
    if (read_values[1] == 0)
      return;

    // Get returned values -
    tier_ends_at = read_values[0];
    // Indices are stored as 1 + (actual index), to avoid conflicts with a default 0 value
    tier_index = read_values[1] - 1;
    tier_tokens_remaining = read_values[2];

    // Overwrite previous buffer, and create new 'readMulti' calldata buffer
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Push tier name, tier token price, modifiable status, and tier whitelist status storage locations to buffer
    uint name_storage_offset = 32 + (192 * tier_index) + uint(CROWDSALE_TIERS);
    ptr.cdPush(bytes32(name_storage_offset)); // Tier name
    ptr.cdPush(bytes32(64 + name_storage_offset)); // Tier purchase price
    ptr.cdPush(bytes32(128 + name_storage_offset)); // Tier modifiability status
    ptr.cdPush(bytes32(160 + name_storage_offset)); // Tier whitelist status
    // Read from storage and get return values
    read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 4);

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
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(6));
    // Get tier offset storage location
    uint tier_info_location = 32 + (192 * _index) + uint(CROWDSALE_TIERS);
    // Push tier name, sell cap, duration, and modifiable status storage locations to buffer
    ptr.cdPush(bytes32(tier_info_location)); // Name
    ptr.cdPush(bytes32(32 + tier_info_location)); // Token sell cap
    ptr.cdPush(bytes32(64 + tier_info_location)); // Tier purchase price
    ptr.cdPush(bytes32(96 + tier_info_location)); // Tier duration
    ptr.cdPush(bytes32(128 + tier_info_location)); // Modifiability status
    ptr.cdPush(bytes32(160 + tier_info_location)); // Whitelist enabled status
    // Read from storage and store return in buffer
    bytes32[] memory read_values = ptr.readMultiFrom(_storage);
    // Ensure correct return length
    assert(read_values.length == 6);

    // Get returned values -
    tier_name = read_values[0];
    tier_sell_cap = uint(read_values[1]);
    tier_price = uint(read_values[2]);
    tier_duration = uint(read_values[3]);
    duration_is_modifiable = (read_values[4] == 0 ? false : true);
    whitelist_enabled = (read_values[5] == 0 ? false : true);
  }

  /*
  Returns the maximum amount of wei to raise, as well as the total amount of tokens that can be sold

  @param _storage: The storage address of the crowdsale application
  @param _exec_id: The execution id of the application
  @return wei_raise_cap: The maximum amount of wei to raise
  @return total_sell_cap: The maximum amount of tokens to sell
  */
  function getCrowdsaleMaxRaise(address _storage, bytes32 _exec_id) public view returns (uint wei_raise_cap, uint total_sell_cap) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(3));
    // Push crowdsale tier list length, token decimals, and token name storage locations to buffer
    ptr.cdPush(CROWDSALE_TIERS);
    ptr.cdPush(TOKEN_DECIMALS);
    ptr.cdPush(TOKEN_NAME);
    // Read from storage
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 3);

    // Get number of crowdsale tiers
    uint num_tiers = read_values[0];
    // Get number of token decimals
    uint num_decimals = read_values[1];

    // If the token has not been set, return
    if (read_values[2] == 0)
      return (0, 0);

    // Overwrite previous buffer - push exec id, data read offset, and read size to buffer
    ptr.cdOverwrite(RD_MULTI);
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2 * num_tiers));
    // Loop through tiers and get sell cap and purchase price for each tier
    for (uint i = 0; i < num_tiers; i++) {
      ptr.cdPush(bytes32(64 + (192 * i) + uint(CROWDSALE_TIERS))); // token sell cap
      ptr.cdPush(bytes32(96 + (192 * i) + uint(CROWDSALE_TIERS))); // tier purchase price
    }

    // Read from storage
    read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2 * num_tiers);

    // Loop through and get wei raise cap and token sell cap
    for (i = 0; i < read_values.length; i+=2) {
      total_sell_cap += read_values[i];
      // Increase maximum wei able to be raised - (tier token sell cap) * (tier price in wei) / (10 ^ decimals)
      wei_raise_cap += (read_values[i] * read_values[i + 1]) / (10 ** num_decimals);
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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and crowdsale tier list length location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(CROWDSALE_TIERS);
    // Read from storage and get list length
    uint list_length = uint(ptr.readSingleFrom(_storage));

    // Overwrite previous buffer, and create 'readMulti' calldata buffer
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(list_length));
    // Loop over each tier name list location and add to buffer
    for (uint i = 0; i < list_length; i++)
      ptr.cdPush(bytes32(32 + (192 * i) + uint(CROWDSALE_TIERS)));

    // Read from storage and return
    crowdsale_tiers = ptr.readMultiFrom(_storage);
    // Ensure correct return length
    assert(crowdsale_tiers.length == list_length);
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
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(3 + _index));
    // Add crowdsale tier list length and crowdsale start time to buffer
    ptr.cdPush(CROWDSALE_TIERS);
    ptr.cdPush(CROWDSALE_START_TIME);
    // Get storage read offset for initial tier duration, then loop over each tier until _index and add their duration storage locations to the read buffer
    bytes32 duration_offset = bytes32(128 + uint(CROWDSALE_TIERS));
    for (uint i = 0; i <= _index; i++) {
      ptr.cdPush(duration_offset);
      // Increment the duration offset to the next index in the array
      duration_offset = bytes32(192 + uint(duration_offset));
    }
    // Read from storage and store return in buffer
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 3 + _index);

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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id to buffer
    ptr.cdPush(_exec_id);
    // Push crowdsale total tokens sold location to buffer
    ptr.cdPush(CROWDSALE_TOKENS_SOLD);
    // Read from storage and return
    tokens_sold = uint(ptr.readSingleFrom(_storage));
  }

  /*
  Returns whitelist information for a given buyer

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _tier_index: The index of the tier about which the whitelist information will be pulled
  @param _buyer: The address of the user whose whitelist status will be returned
  @return minimum_contribution: The minimum ammount of tokens the buyer must purchase during this tier
  @return max_spend_remaining: The maximum amount of wei able to be spent by the buyer during this tier
  */
  function getWhitelistStatus(address _storage, bytes32 _exec_id, uint _tier_index, address _buyer) public view
  returns (uint minimum_contribution, uint max_spend_remaining) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    // Get buyer whitelist location for the tier -
    bytes32 location = keccak256(keccak256(_buyer), keccak256(_tier_index, SALE_WHITELIST));
    // Push whitelist minimum contribution location to buffer
    ptr.cdPush(location);
    // Push whitlist maximum spend amount remaining location to buffer
    ptr.cdPush(bytes32(32 + uint(location)));

    // Read from storage and return
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2);

    minimum_contribution = read_values[0];
    max_spend_remaining = read_values[1];
  }

  /*
  Returns the list of whitelisted buyers for a given tier

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _tier_index: The index of the tier about which the whitelist information will be pulled
  @return num_whitelisted: The length of the tier's whitelist array
  @return whitelist: The tier's whitelisted addresses
  */
  function getTierWhitelist(address _storage, bytes32 _exec_id, uint _tier_index) public view returns (uint num_whitelisted, address[] memory whitelist) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and tier whitelist storage location to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(keccak256(_tier_index, SALE_WHITELIST));
    // Read from storage and get returned tier whitelist length
    num_whitelisted = uint(ptr.readSingleFrom(_storage));

    // Overwrite previous buffer and loop through the whitelist number to get each whitelisted address
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_whitelisted));
    // Loop through the number of whitelisted addresses, and push each to the calldata buffer to be read from storage
    for (uint i = 0; i < num_whitelisted; i++)
      ptr.cdPush(bytes32(32 + (32 * i) + uint(keccak256(_tier_index, SALE_WHITELIST))));

    // Read from storage and return
    whitelist = ptr.readMultiFrom(_storage).toAddressArr();
    // Ensure correct return length
    assert(whitelist.length == num_whitelisted);
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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and owner balance location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(keccak256(keccak256(_owner), TOKEN_BALANCES));
    // Read from storage
    owner_balance = uint(ptr.readSingleFrom(_storage));
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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and spender allowance location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(keccak256(keccak256(_spender), keccak256(keccak256(_owner), TOKEN_ALLOWANCES)));
    // Read from storage
    allowed = uint(ptr.readSingleFrom(_storage));
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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and token decimals storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(TOKEN_DECIMALS);
    // Read from storage
    token_decimals = uint(ptr.readSingleFrom(_storage));
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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and token total supply storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(TOKEN_TOTAL_SUPPLY);
    // Read from storage
    total_supply = uint(ptr.readSingleFrom(_storage));
  }

  /*
  Returns the name field of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_name: The name of the token
  */
  function name(address _storage, bytes32 _exec_id) public view returns (bytes32 token_name) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and token name storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(TOKEN_NAME);
    // Read from storage
    token_name = ptr.readSingleFrom(_storage);
  }

  /*
  Returns the ticker symbol of a given token app instance

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return token_symbol: The token's ticker symbol
  */
  function symbol(address _storage, bytes32 _exec_id) public view returns (bytes32 token_symbol) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and token symbol storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(TOKEN_SYMBOL);
    // Read from storage
    token_symbol = ptr.readSingleFrom(_storage);
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
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Place token name, symbol, decimals, and total supply storage locations in buffer
    ptr.cdPush(TOKEN_NAME);
    ptr.cdPush(TOKEN_SYMBOL);
    ptr.cdPush(TOKEN_DECIMALS);
    ptr.cdPush(TOKEN_TOTAL_SUPPLY);

    // Read from storage
    bytes32[] memory read_values = ptr.readMultiFrom(_storage);
    // Ensure correct return length
    assert(read_values.length == 4);

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
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and transfer agent status storage location to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(keccak256(keccak256(_agent), TOKEN_TRANSFER_AGENTS));
    // Read from storage
    is_transfer_agent = (ptr.readSingleFrom(_storage) == 0 ? false : true);
  }

  /*
  Returns information on a reserved token address (the crowdsale admin can set reserved tokens for addresses before initializing the crowdsale)

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under storage for this app instance is located
  @return num_destinations: The length of the crowdsale's reserved token destination array
  @return reserved_destinations: A list of the addresses which have reserved tokens or percents
  */
  function getReservedTokenDestinationList(address _storage, bytes32 _exec_id) public view
  returns (uint num_destinations, address[] memory reserved_destinations) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and reserved token destination list location to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(TOKEN_RESERVED_DESTINATIONS);
    // Read reserved destination list length from storage
    num_destinations = uint(ptr.readSingleFrom(_storage));

    // If num_destinations is 0, return now
    if (num_destinations == 0)
      return (0, reserved_destinations);

    /// Loop through each list in storage, and get each address -

    // Overwrite previous buffer with new 'readMulti' calldata buffer -
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_destinations));
    // Add each destination index location to calldata
    for (uint i = 1; i <= num_destinations; i++)
      ptr.cdPush(bytes32((32 * i) + uint(TOKEN_RESERVED_DESTINATIONS)));

    // Read from storage, and return data to buffer
    reserved_destinations = ptr.readMultiFrom(_storage).toAddressArr();
    // Ensure correct return length
    assert(reserved_destinations.length == num_destinations);
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
  returns (uint destination_list_index, uint num_tokens, uint num_percent, uint percent_decimals) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(4));
    // Push reserved destination information storage locations to buffer -
    uint base_loc = uint(keccak256(keccak256(_destination), TOKEN_RESERVED_ADDR_INFO));
    ptr.cdPush(bytes32(base_loc));
    ptr.cdPush(bytes32(32 + base_loc));
    ptr.cdPush(bytes32(64 + base_loc));
    ptr.cdPush(bytes32(96 + base_loc));

    // Read from storage, and return data to buffer
    bytes32[] memory read_values = ptr.readMultiFrom(_storage);
    // Ensure correct return length
    assert(read_values.length == 4);

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
}
