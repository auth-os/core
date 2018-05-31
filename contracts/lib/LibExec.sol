pragma solidity ^0.4.23;

import "./Buffers.sol";

library LibExec {

  struct Exec {
    Action current;
    function () pure returns (Action) storing;
    function () pure returns (Action) emitting;
    function () pure returns (Action) paying;
    Buffers.Buffer buffer;
  }

  enum Action {
    INVALID, NONE, STORING, EMITTING, PAYING
  }

  function _invalid() internal pure returns (Action) { return Action.INVALID; }
  function _storing() internal pure returns (Action) { return Action.STORING; }
  function _emitting() internal pure returns (Action) { return Action.EMITTING; }
  function _paying() internal pure returns (Action) { return Action.PAYING; }

  function start(
    Exec memory _exec,
    function () pure returns (Action) _action_get
  ) internal pure {
    if (_exec.current != Action.NONE)
      Errors.except('Error at LibExec.start: currently performing another action');

    _exec.current = _action_get();
    if (_exec.current == Action.INVALID || _exec.current == Action.NONE)
      Errors.except('Error at LibExec.start: invalid action returned');
  }

  function finish(
    Exec memory _exec,
    function () pure returns (Action) _action_get
  ) internal pure {
    if (_exec.current != _action_get() || _action_get == _invalid)
      Errors.except('Error at LibExec.finish: action not being performed');

    _exec.current = Action.NONE;
    _action_get = _invalid;
  }

  function checks() internal pure returns (Exec memory) {
    return Exec({
      current: Action.INVALID,
      storing: _invalid,
      emitting: _invalid,
      paying: _invalid,
      buffer: Buffers.empty()
    });
  }

  function effects(Exec memory _exec, bool stores, bool emits, bool pays) internal pure {
    if (!stores && !emits && !pays)
      Errors.except('Error at LibExec.effects: no effects specified');

    if (
      _exec.current != Action.INVALID ||
      _exec.storing != _invalid ||
      _exec.emitting != _invalid ||
      _exec.paying != _invalid
    ) Errors.except('Error at LibExec.effects: invalid execution state');

    if (stores)
      _exec.storing = _storing;
    else if (emits)
      _exec.emitting = _emitting;
    else if (pays)
      _exec.paying = _paying;

    _exec.current = Action.NONE;
  }

  function finalize(Exec memory _exec) internal pure {
    if (_exec.current != Action.NONE)
      Errors.except('Error at LibExec.finalize: invalid current action');
    bytes memory buffer = _exec.buffer.buffer;
    assembly {
      // Set data read offset
      mstore(sub(buffer, 0x20), 0x20)
      // Revert buffer to storage
      revert(sub(buffer, 0x20), add(0x40, mload(buffer)))
    }
  }
}
