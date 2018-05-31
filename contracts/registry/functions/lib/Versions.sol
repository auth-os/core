pragma solidity ^0.4.23;

import "./Apps.sol";

library Versions {

  using Virtual for Virtual.Wrapper;

  // Version wrapper type -
  struct Version {
    Virtual.Wrapper self; // Reference to the version's base storage location
    Virtual.Word name; // Reference to the version's name
    Virtual.Bool is_finalized; // Reference to the version's status
    Virtual.Address storage_addr; // Reference to the version's default storage address
    Virtual.Word init_selector; // Reference to the version's init function selector
    Virtual.Address init_addr; // Reference to the version's initialization address
    Virtual.Words description; // Reference to the version's description
    Virtual.List functions; // Reference to the version's function selector list
    Virtual.List function_addrs; // Reference to the version's address list
  }

  struct Feature {
    function (uint) pure once;
    function (uint) pure done;
    function (uint) pure always;
  }

  /// Storage seeds

  // Version base storage seed
  bytes32 internal constant VERSIONS = keccak256("versions");
  // Version description storage seed
  bytes32 internal constant VER_DESC = keccak256("ver_desc");
  // Version status storage seed
  bytes32 internal constant VER_IS_FINALIZED = keccak256("ver_is_finalized");
  // Version function selector list storage seed
  bytes32 internal constant VER_FUNCTION_LIST = keccak256("ver_functions_list");
  // Version address list storage seed
  bytes32 internal constant VER_ADDR_LIST = keccak256("ver_function_addrs");
  // Version default storage address storage seed
  bytes32 internal constant VER_STORAGE_IMPL = keccak256("ver_storage_impl");
  // Version initialization address storage seed
  bytes32 internal constant VER_INIT_ADDR = keccak256("ver_init_addr");
  // Version initialization function selector storage seed
  bytes32 internal constant VER_INIT_SELECTOR = keccak256("ver_init_selector");

  /// Storage location resolution functions

  // A version's name is stored at the version's own base storage location
  function _name(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return _version.base();
  }

  // A version's status is stored at the hash of VER_IS_FINALIZED and the version's
  // base storage location
  function _is_finalized(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_IS_FINALIZED, _version.base());
  }

  // A version's default storage address is stored at the hash of VER_STORAGE_IMPL
  // and the version's base storage location
  function _storage_addr(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_STORAGE_IMPL, _version.base());
  }

  // A version's init function selector is stored at the hash of VER_INIT_SELECTOR
  // and the version's base storage location
  function _init_selector(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_INIT_SELECTOR, _version.base());
  }

  // A version's initialization address is stored at the hash of VER_INIT_ADDR
  // and the version's base storage location
  function _init_addr(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_INIT_ADDR, _version.base());
  }

  // A version's description is stored at the hash of VER_DESC and the version's
  // base storage location
  function _description(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_DESC, _version.base());
  }

  // A version's function selector list is stored at the hash of VER_FUNCTION_LIST
  // and the version's base storage location
  function _functions(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_FUNCTION_LIST, _version.base());
  }

  // A version's function address list is stored at the hash of VER_ADDR_LIST
  // and the version's base storage location
  function _function_addrs(Virtual.Wrapper memory _version) internal pure returns (bytes32) {
    return keccak256(VER_ADDR_LIST, _version.base());
  }

  /// Other functions

  // Returns the Version struct released under the application with name _version_name
  function version(Apps.Application memory _app, bytes32 _version_name) internal pure returns (Version memory ver) {
    // Create Version Wrapper pointer -
    // The base storage location hashes the version name with the VERSIONS seed, as well as the
    // version's base storage location
    ver.self.initWrapper(
      keccak256(_version_name, VERSIONS, _app.self.base()),
      _app.self.execID()
    );

    // Declare version fields in storage
    ver.self.hasField(ver.name, _name);
    ver.self.hasField(ver.is_finalized, _is_finalized);
    ver.self.hasField(ver.storage_addr, _storage_addr);
    ver.self.hasField(ver.init_selector, _init_selector);
    ver.self.hasField(ver.init_addr, _init_addr);
    ver.self.hasField(ver.description, _description);
    ver.self.hasField(ver.functions, _functions);
    ver.self.hasField(ver.function_addrs, _function_addrs);
  }
}
