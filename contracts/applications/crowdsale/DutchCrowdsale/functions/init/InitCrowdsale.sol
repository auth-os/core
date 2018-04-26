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

  // Whether the crowdsale and token are initialized, and the application is ready to run
  bytes32 internal constant CROWDSALE_IS_INIT = keccak256("crowdsale_is_init");

  // Whether or not the crowdsale is post-purchase
  bytes32 internal constant CROWDSALE_IS_FINALIZED = keccak256("crowdsale_is_finalized");

  // Storage location of the maximum number of tokens to sell
  bytes32 internal constant MAX_TOKEN_SELL_CAP = keccak256("token_sell_cap");

  // Storage location for the amount of tokens still available for purchase in this crowdsale
  bytes32 internal constant TOKENS_REMAINING = keccak256("crowdsale_tokens_remaining");

  // Storage location of the minimum amount of tokens allowed to be purchased
  bytes32 internal constant CROWDSALE_MINIMUM_CONTRIBUTION = keccak256("crowdsale_min_cap");

  // Maps addresses to a boolean indicating whether or not this address has contributed
  // At its base location, stores the amount of unique contributors so far in this crowdsale
  bytes32 internal constant CROWDSALE_UNIQUE_CONTRIBUTORS = keccak256("crowdsale_contributors");

  // Storage location of crowdsale start time
  bytes32 internal constant CROWDSALE_STARTS_AT = keccak256("crowdsale_starts_at");

  // Storage location of duration of crowdsale
  bytes32 internal constant CROWDSALE_DURATION = keccak256("crowdsale_duration");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 internal constant STARTING_SALE_RATE = keccak256("crowdsale_start_rate");

  // Storage location of the token/wei rate at the beginning of the sale
  bytes32 internal constant ENDING_SALE_RATE = keccak256("crowdsale_end_rate");

  // Storage location of team funds wallet
  bytes32 internal constant WALLET = keccak256("crowdsale_wallet");

  // Storage location of amount of wei raised during the crowdsale, total
  bytes32 internal constant WEI_RAISED = keccak256("crowdsale_wei_raised");

  // Whether or not the crowdsale is whitelist-enabled
  bytes32 internal constant SALE_IS_WHITELISTED = keccak256("crowdsale_is_whitelisted");

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

  /// FUNCTION SELECTORS ///

  // Function selector for storage "read"
  // read(bytes32 _exec_id, bytes32 _location) view returns (bytes32 data_read);
  bytes4 internal constant RD_SING = bytes4(keccak256("read(bytes32,bytes32)"));

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 internal constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

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
  @param _sale_is_whitelisted: Whether the dutch auction is whitelist-enabled or not
  @param _admin: The address to set as crowdsale admin - is allowed to complete initialization of the crowdsale
  @return store_data: A formatted storage request
  */
  function init(
    address _wallet,
    uint _total_supply,
    uint _max_amount_to_sell,
    uint _starting_rate,
    uint _ending_rate,
    uint _duration,
    uint _start_time,
    bool _sale_is_whitelisted,
    address _admin
  ) public view returns (bytes32[] memory store_data) {
    // Ensure valid input
    if (
      _wallet == address(0)
      || _max_amount_to_sell == 0
      || _max_amount_to_sell > _total_supply
      || _starting_rate <= _ending_rate
      || _ending_rate == 0
      || _start_time <= now
      || _duration + _start_time <= _start_time
      || _admin == address(0)
    ) bytes32("ImproperInitialization").trigger();

    // Create storage data return buffer in memory
    uint ptr = ReadFromBuffers.stBuff(0, 0);
    // Push admin address, team wallet, token sell cap, and start/end sale rates to buffer
    ptr.stPush(ADMIN, bytes32(_admin));
    ptr.stPush(WALLET, bytes32(_wallet));
    ptr.stPush(TOKENS_REMAINING, bytes32(_max_amount_to_sell));
    ptr.stPush(STARTING_SALE_RATE, bytes32(_starting_rate));
    ptr.stPush(ENDING_SALE_RATE, bytes32(_ending_rate));
    // Push token totalsupply, crowdsale duration, and crowdsale start time to buffer
    ptr.stPush(TOKEN_TOTAL_SUPPLY, bytes32(_total_supply));
    ptr.stPush(CROWDSALE_DURATION, bytes32(_duration));
    ptr.stPush(CROWDSALE_STARTS_AT, bytes32(_start_time));
    // Push admin balance, token sell cap, and crowdsale whitelist status to buffer
    ptr.stPush(keccak256(keccak256(_admin), TOKEN_BALANCES), bytes32(_total_supply - _max_amount_to_sell));
    ptr.stPush(MAX_TOKEN_SELL_CAP, bytes32(_max_amount_to_sell));
    ptr.stPush(SALE_IS_WHITELISTED, (_sale_is_whitelisted ? bytes32(1) : bytes32(0)));

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
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    // Push tokens remaining and max tokens sell cap read locations to buffer
    ptr.cdPush(TOKENS_REMAINING);
    ptr.cdPush(MAX_TOKEN_SELL_CAP);
    // Read from storage
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2);

    // Get number of tiers and tokens sold
    uint tokens_remaining = read_values[0];
    max_sellable = read_values[1];

    // Return values
    is_crowdsale_full = (tokens_remaining == 0 ? true : false);
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
  @return start_time: The start time of the crowdsale
  @return end_time: The time at which the crowdsale ends
  */
  function getCrowdsaleStartAndEndTimes(address _storage, bytes32 _exec_id) public view returns (uint start_time, uint end_time) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, read size, start time, and total duration locations to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    ptr.cdPush(CROWDSALE_STARTS_AT);
    ptr.cdPush(CROWDSALE_DURATION);
    // Read from storage
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();
    // Ensure correct return length
    assert(read_values.length == 2);

    // Get return values
    start_time = read_values[0];
    end_time = start_time + read_values[1];
  }

  /*
  Returns information on the status of the sale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return current_rate: The current rate at which tokens are being sold. Rate is in wei/10^18 units
  @return time_remaining: The amount of time remaining in the crowdsale
  @return tokens_remaining: The amount of tokens still available to be sold
  */
  function getCrowdsaleStatus(address _storage, bytes32 _exec_id) public view
  returns (uint current_rate, uint time_remaining, uint tokens_remaining) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(5));
    // Push crowdsale starting and ending rates, and crowdsale start time storage locations to buffer
    ptr.cdPush(STARTING_SALE_RATE);
    ptr.cdPush(ENDING_SALE_RATE);
    ptr.cdPush(CROWDSALE_STARTS_AT);
    // Push crowdsale duration and tokens left to buffer
    ptr.cdPush(CROWDSALE_DURATION);
    ptr.cdPush(TOKENS_REMAINING);
    // Read from storage, and store return in buffer
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();

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
  @return current_rate: The current rate of wei/10^18 token units
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
    time_elapsed *= (10 ** 18);
    current_rate = (_start_rate - _end_rate) * (time_elapsed / _duration);
    current_rate /= (10 ** 18); // Remove additional precision decimals
    current_rate = _start_rate - current_rate;
  }

  /*
  Returns the number of tokens sold - maximum number to sell minus tokens remaining

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return tokens_sold: The number of tokens sold this crowdsale so far
  */
  function getTokensSold(address _storage, bytes32 _exec_id) public view returns (uint tokens_sold) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    // Push token sell cap and tokens remaining storage locations to buffer
    ptr.cdPush(MAX_TOKEN_SELL_CAP);
    ptr.cdPush(TOKENS_REMAINING);
    // Read from storage, and store return in buffer
    uint[] memory read_values = ptr.readMultiFrom(_storage).toUintArr();

    // Get return value -
    tokens_sold = read_values[0] - read_values[1];
  }

  /*
  Returns whitelist information for a given buyer

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @param _buyer: The address of the user whose whitelist status will be returned
  @return minimum_contribution: The minimum ammount of tokens the buyer must purchase
  @return max_spend_remaining: The maximum amount of wei able to be spent
  */
  function getWhitelistStatus(address _storage, bytes32 _exec_id, address _buyer) public view
  returns (uint minimum_contribution, uint max_spend_remaining) {
    // Create 'readMulti' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(2));
    // Get buyer whitelist location -
    bytes32 location = keccak256(keccak256(_buyer), SALE_WHITELIST);
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
  Returns the list of whitelisted buyers for the crowdsale

  @param _storage: The address where application storage is located
  @param _exec_id: The application execution id under which storage for this instance is located
  @return num_whitelisted: The length of the crowdsale's whitelist array
  @return whitelist: The crowdsale's whitelisted addresses
  */
  function getCrowdsaleWhitelist(address _storage, bytes32 _exec_id) public view
  returns (uint num_whitelisted, address[] memory whitelist) {
    // Create 'read' calldata buffer in memory
    uint ptr = ReadFromBuffers.cdBuff(RD_SING);
    // Push exec id and whitelist storage location to calldata buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(SALE_WHITELIST);
    // Read from storage and get returned tier whitelist length
    num_whitelisted = uint(ptr.readSingleFrom(_storage));

    // If there are not whitelisted addresses, return
    if (num_whitelisted == 0)
      return (num_whitelisted, whitelist);

    // Overwrite previous buffer and loop through the whitelist length to get each whitelisted address
    ptr.cdOverwrite(RD_MULTI);
    // Push exec id, data read offset, and read size to buffer
    ptr.cdPush(_exec_id);
    ptr.cdPush(0x40);
    ptr.cdPush(bytes32(num_whitelisted));
    // Loop through the number of whitelisted addresses, and push each to the calldata buffer to be read from storage
    for (uint i = 0; i < num_whitelisted; i++)
      ptr.cdPush(bytes32(32 + (32 * i) + uint(SALE_WHITELIST)));

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
}
