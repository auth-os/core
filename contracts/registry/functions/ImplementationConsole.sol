pragma solidity ^0.4.21;

library ImplementationConsole {

  /// PROVIDER STORAGE ///

  // Provider namespace - all app and version storage is seeded to a provider
  // [PROVIDERS][provider_id]
  bytes32 public constant PROVIDERS = keccak256("registry_providers");

  /// APPLICATION STORAGE ///

  // Application namespace - all app info and version storage is mapped here
  // [PROVIDERS][provider_id][APPS][app_name]
  bytes32 public constant APPS = keccak256("apps");

  /// VERSION STORAGE ///

  // Version namespace - all version and function info is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS]
  bytes32 public constant VERSIONS = keccak256("versions");

  // Version "is finalized" location - whether a version is ready for use (all intended functions implemented)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_IS_FINALIZED] = bool is_finalized
  bytes32 public constant VER_IS_FINALIZED = keccak256("ver_is_finalized");

  // Version function list location - (bytes4 array)
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_LIST] = bytes4[] function_signatures
  bytes32 public constant VER_FUNCTION_LIST = keccak256("ver_functions_list");

  // Version function address location - stores the address where each corresponding version's function is located
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_name][VER_FUNCTION_ADDRESSES] = address[] function_addresses
  bytes32 public constant VER_FUNCTION_ADDRESSES = keccak256("ver_function_addrs");

  /// FUNCTION STORAGE ///

  // Function namespace - function information is mapped here
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature]
  bytes32 public constant FUNCTIONS = keccak256("functions");

  // Storage location of a function's implementing address
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature][FUNC_IMPL_ADDR] = address implementation
  bytes32 public constant FUNC_IMPL_ADDR = keccak256("function_impl_addr");

  // Storage location of a function's description
  // [PROVIDERS][provider_id][APPS][app_hash][VERSIONS][ver_hash][FUNCTIONS][func_signature][FUNC_DESC] = bytes description
  bytes32 public constant FUNC_DESC = keccak256("func_desc");

  /// FUNCTION SELECTORS ///

  // Function selector for storage 'readMulti'
  // readMulti(bytes32 exec_id, bytes32[] locations)
  bytes4 public constant RD_MULTI = bytes4(keccak256("readMulti(bytes32,bytes32[])"));

  /// FUNCTIONS ///

  struct FunctionInfo {
    bytes4 rd_multi;
    bytes32 app_storage_loc;
    bytes32 ver_storage_loc;
    bytes32 ver_status_loc;
    bytes32 ver_func_list_loc;
    bytes32 ver_addr_list_loc;
    bytes32 func_storage_seed;
    bytes32 func_impl_storage_seed;
  }

  /*
  Adds functions and their implementing addresses to a non-finalized version

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Registry application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _app: The name of the application under which the version is registered
  @param _version: The name of the version to add functions to
  @param _function_sigs: An array of function selectors the version will implement
  @param _function_addrs: The corresponding addresses which implement the given functions
  @return store_data: A formatted storage request, which will be interpreted by the sender storage proxy to store version info
  */
  function addFunctions(bytes _context, bytes32 _app, bytes32 _version, bytes4[] _function_sigs, address[] _function_addrs) public view
  returns (bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 64);
    require(_app != bytes32(0) && _version != bytes32(0));
    require(_function_sigs.length == _function_addrs.length && _function_sigs.length > 0);

    address provider;
    bytes32 exec_id;

    // Parse context array and get sender address and execution id
    (provider, exec_id) = parse(_context);

    // Initialize struct in memory to hold values
    FunctionInfo memory func_info = FunctionInfo({
      rd_multi: RD_MULTI,
      app_storage_loc: keccak256(keccak256(provider), PROVIDERS),
      // Placeholders
      ver_storage_loc: 0,
      ver_status_loc: 0,
      ver_func_list_loc: 0,
      ver_addr_list_loc: 0,
      func_storage_seed: 0,
      func_impl_storage_seed: FUNC_IMPL_ADDR
    });

    // Get app base storage location
    func_info.app_storage_loc = keccak256(APPS, func_info.app_storage_loc);
    func_info.app_storage_loc = keccak256(keccak256(_app), func_info.app_storage_loc);
    // Get version base storage location
    func_info.ver_storage_loc = keccak256(VERSIONS, func_info.app_storage_loc);
    func_info.ver_storage_loc = keccak256(keccak256(_version), func_info.ver_storage_loc);
    // Get version status, function list, and function address list storage locations
    func_info.ver_status_loc = keccak256(VER_IS_FINALIZED, func_info.ver_storage_loc);
    func_info.ver_func_list_loc = keccak256(VER_FUNCTION_LIST, func_info.ver_storage_loc);
    func_info.ver_addr_list_loc = keccak256(VER_FUNCTION_ADDRESSES, func_info.ver_storage_loc);
    // Get function storage seed
    func_info.func_storage_seed = keccak256(FUNCTIONS, func_info.ver_storage_loc);

    assembly {
      // Ensure application and version are registered, and that the version is not already finalized.
      // Additionally, get version function and address list lengths -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, registry execution id, data read offset, and read size in calldata
      mstore(ptr, mload(func_info))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 5)
      // Place app base storage, version base storage, and version finalization status storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, func_info)))
      mstore(add(0x84, ptr), mload(add(0x40, func_info)))
      mstore(add(0xa4, ptr), mload(add(0x60, func_info)))
      // Place version function and address list length storage locations in calldata
      mstore(add(0xc4, ptr), mload(add(0x80, func_info)))
      mstore(add(0xe4, ptr), mload(add(0xa0, func_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, caller, ptr, 0x0104, ptr, 0xe0)
      ) { revert (0, 0) }

      // Get returned app storage value - if zero, app is not registered: revert
      if iszero(mload(add(0x40, ptr))) { revert (0, 0) }
      // Get returned version storage value - if zero, version is not registered: revert
      if iszero(mload(add(0x60, ptr))) { revert (0, 0) }
      // Get returned version status - if nonzero, version is already finalized: revert
      if gt(mload(add(0x80, ptr)), 0) { revert (0, 0) }
      // Get version function list length, and compare to address list length. They should always be equal
      let ver_lists_length := mload(add(0xa0, ptr))
      if iszero(eq(ver_lists_length, mload(add(0xc0, ptr)))) { revert (0, 0) }

      // App and version are registered, and version has not been finalized: store functions and their addresses -

      // Get return write size -
      let size := add(4, mul(8, mload(_function_sigs)))

      // Allocate space for return storage request
      store_data := add(0x20, msize)
      // Set return length
      mstore(store_data, size)

      // Set return values -

      // Set new version list lengths
      mstore(add(0x20, store_data), mload(add(0x80, func_info)))
      mstore(add(0x40, store_data), add(ver_lists_length, mload(_function_sigs)))
      mstore(add(0x60, store_data), mload(add(0xa0, func_info)))
      mstore(add(0x80, store_data), add(ver_lists_length, mload(_function_sigs)))
      // Loop through functions and addresses - push each to end of their respective version lists
      let offset := 0x20
      for { } lt(offset, add(0x20, mul(0x20, mload(_function_sigs)))) { offset := add(0x20, offset) } {
        // Push function signature and address to lists -

        // Place end of function list length in return request
        mstore(add(add(0xa0, mul(8, sub(offset, 0x20))), store_data), add(offset, mload(add(0x80, func_info))))
        // Place function signature in return request
        mstore(add(add(0xc0, mul(8, sub(offset, 0x20))), store_data), mload(add(offset, _function_sigs)))
        // Place end of address list in return request
        mstore(add(add(0xe0, mul(8, sub(offset, 0x20))), store_data), add(offset, mload(add(0xa0, func_info))))
        // Place function address in return request
        mstore(add(add(0x0100, mul(8, sub(offset, 0x20))), store_data), mload(add(offset, _function_addrs)))

        // Store function information in function storage -

        // Store function storage seed in temporary space, and hash with function signature
        mstore(0x20, mload(add(0xc0, func_info)))
        mstore(0, mload(add(offset, _function_sigs)))
        mstore(0, keccak256(0, 0x04))
        // Hash function storage seed and function signature hash to get function storage location
        mstore(0x20, keccak256(0, 0x40))
        // Place function storage location and function signature in return request
        mstore(add(add(0x0120, mul(8, sub(offset, 0x20))), store_data), mload(0x20))
        mstore(add(add(0x0140, mul(8, sub(offset, 0x20))), store_data), mload(add(offset, _function_sigs)))
        // Store function implementation address storage seed in temporary space, and hash with function storage seed
        mstore(0, mload(add(0xe0, func_info)))
        mstore(0x20, keccak256(0, 0x40))
        // Place function impl address storage location and function impl address in return request
        mstore(add(add(0x0160, mul(8, sub(offset, 0x20))), store_data), mload(0x20))
        mstore(add(add(0x0180, mul(8, sub(offset, 0x20))), store_data), mload(add(offset, _function_addrs)))
      }
    }
  }

  struct DescribeFunction {
    bytes4 rd_multi;
    bytes32 app_storage_loc;
    bytes32 ver_storage_loc;
    bytes32 ver_status_loc;
    bytes32 func_storage_loc;
    bytes32 func_desc_loc;
  }

  /*
  Adds a description to an added function

  @param _context: A 64-byte array containing execution context for the application. In order:
    1. Registry application execution id
    2. Original script sender (address, padded to 32 bytes)
  @param _app: The name of the application under which the version is registered
  @param _version: The name of the version to add functions to
  @param _function_sig: The function signature to which the description will be added
  @param _function_description: The bytes of a function's description
  @return store_data: A formatted storage request, which will be interpreted by the sender storage proxy to store version info
  */
  function describeFunction(bytes _context, bytes32 _app, bytes32 _version, bytes4 _function_sig, bytes _function_description) public view
  returns (bytes32[] store_data) {
    // Ensure input is correctly formatted
    require(_context.length == 64);
    require(_app != bytes32(0) && _version != bytes32(0));
    require(_function_sig != bytes4(0) && _function_description.length > 0);

    address provider;
    bytes32 exec_id;

    // Parse context array and get sender address and execution id
    (provider, exec_id) = parse(_context);

    // Initialize struct in memory to hold values
    DescribeFunction memory func_info = DescribeFunction({
      rd_multi: RD_MULTI,
      app_storage_loc: keccak256(keccak256(provider), PROVIDERS),
      // Placeholders
      ver_storage_loc: 0,
      ver_status_loc: 0,
      func_storage_loc: 0,
      func_desc_loc: 0
    });

    // Get app base storage location
    func_info.app_storage_loc = keccak256(APPS, func_info.app_storage_loc);
    func_info.app_storage_loc = keccak256(keccak256(_app), func_info.app_storage_loc);
    // Get version base storage location
    func_info.ver_storage_loc = keccak256(VERSIONS, func_info.app_storage_loc);
    func_info.ver_storage_loc = keccak256(keccak256(_version), func_info.ver_storage_loc);
    // Get version status storage location
    func_info.ver_status_loc = keccak256(VER_IS_FINALIZED, func_info.ver_storage_loc);
    // Get function base storage location
    func_info.func_storage_loc = keccak256(FUNCTIONS, func_info.ver_storage_loc);
    func_info.func_storage_loc = keccak256(keccak256(_function_sig), func_info.func_storage_loc);
    // Get function dscription storage location
    func_info.func_desc_loc = keccak256(FUNC_DESC, func_info.func_storage_loc);

    assembly {
      // Ensure application and version are registered, and that the version is not already finalized.
      // Additionally, ensure function exists -

      // Get pointer to store calldata in
      let ptr := mload(0x40)
      // Place 'readMulti' selector, registry execution id, data read offset, and read size in calldata
      mstore(ptr, mload(func_info))
      mstore(add(0x04, ptr), exec_id)
      mstore(add(0x24, ptr), 0x40)
      mstore(add(0x44, ptr), 4)
      // Place app base storage, version base storage, and version finalization status storage locations in calldata
      mstore(add(0x64, ptr), mload(add(0x20, func_info)))
      mstore(add(0x84, ptr), mload(add(0x40, func_info)))
      mstore(add(0xa4, ptr), mload(add(0x60, func_info)))
      // Place function storage location in calldataa
      mstore(add(0xc4, ptr), mload(add(0x80, func_info)))

      // Read from storage and check return value. Store returned data at pointer
      if iszero(
        staticcall(gas, caller, ptr, 0xe4, ptr, 0xc0)
      ) { revert (0, 0) }

      // Get returned app storage value - if zero, app is not registered: revert
      if iszero(mload(add(0x40, ptr))) { revert (0, 0) }
      // Get returned version storage value - if zero, version is not registered: revert
      if iszero(mload(add(0x60, ptr))) { revert (0, 0) }
      // Get returned version status - if nonzero, version is already finalized: revert
      if gt(mload(add(0x80, ptr)), 0) { revert (0, 0) }
      // Get returned function storage location - if zero, function does not exist: revert
      if iszero(mload(add(0xa0, ptr))) { revert (0, 0) }

      // App and version are registered, and version has not been finalized: store function description -

      // Get return write size -
      let size := add(2, div(mload(_function_description), 0x20))
      if gt(mod(mload(_function_description), 0x20), 0) { size := add(2, size) }

      // Allocate space for return storage request
      store_data := add(0x20, msize)
      // Set return length
      mstore(store_data, size)

      // Set return values -

      // Loop through description and place in return request
      for { let offset := 0x00 } lt(offset, add(0x20, mload(_function_description))) { offset := add(0x20, offset) } {
        // Place end of description list in calldata -
        mstore(add(add(0x20, mul(2, offset)), store_data), add(offset, mload(add(0xa0, func_info))))
        // Place description chunk in calldata
        mstore(add(add(0x40, mul(2, offset)), store_data), mload(add(offset, _function_description)))
      }
    }
  }

  // Parses context array and returns sender address and execution id
  function parse(bytes _context) internal pure returns (address from, bytes32 exec_id) {
    assembly {
      exec_id := mload(add(0x20, _context))
      from := mload(add(0x40, _context))
    }
    // Ensure neither field is zero
    require(from != address(0) && exec_id != bytes32(0));
  }
}
