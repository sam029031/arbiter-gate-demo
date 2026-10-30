// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

/// Subset of the Foundry cheatcode interface, declared by hand so that a proof of
/// concept needs no external dependency and the workspace stays hermetic.
interface Vm {
    function prank(address) external;
    // Two-argument forms set msg.sender AND tx.origin, which is the only way to satisfy
    // a require(msg.sender == tx.origin) guard from inside a test.
    function prank(address, address) external;
    function startPrank(address) external;
    function startPrank(address, address) external;
    function stopPrank() external;
    function deal(address, uint256) external;
    function warp(uint256) external;
    function roll(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function label(address, string calldata) external;
    function store(address, bytes32, bytes32) external;
    function load(address, bytes32) external returns (bytes32);
    // Two worlds from one setup: the victim-loss predicate runs the same scenario with
    // and without the attack and compares what the victim gets back, which is only
    // meaningful if both start from byte-identical state.
    function snapshotState() external returns (uint256);
    function revertToState(uint256) external returns (bool);
    // Measured additions. Across two full runs 33 exploits failed to compile on
    // `vm.sign` alone, and a further handful on addr/assume/fee/difficulty -- every one
    // of them a recall loss caused by this interface being short, not by the attack
    // being wrong. Signature forgery is still refused by the attack-side lint; what is
    // restored here is the ability to write a legitimate signed message.
    function sign(uint256, bytes32) external pure returns (uint8, bytes32, bytes32);
    function addr(uint256) external pure returns (address);
    function assume(bool) external pure;
    function fee(uint256) external;
    function difficulty(uint256) external;
    function prevrandao(bytes32) external;
    function getNonce(address) external returns (uint64);
    function expectEmit(bool, bool, bool, bool) external;
    function recordLogs() external;
}

// File scope, so a contract the agent writes can reach it too. 13 exploits failed to
// compile because `vm` is a member of Harness and an Attacker does not inherit it.
// A plain comment, not a doc comment: solc rejects @notice on a file-level variable.
// Reaching a cheatcode from an attack is still refused by the lint, which is where that
// decision belongs, rather than by an accident of scope.
// Named `vm`, and it used to be `vm_`. The underscore was the whole defect: an agent
// writing an Attacker -- which inherits nothing -- reaches for `vm.warp` the way everyone
// writing Foundry does, and got `Undeclared identifier. Did you mean "Vm"?`. 42 of those
// in one 40-sample run, the largest named error class left after the assert repair, and
// every one of them a turn spent on the harness's spelling rather than on the attack.
// `Harness` no longer declares its own, so there is exactly one `vm` in scope everywhere
// and nothing shadows anything. Reaching a cheatcode FROM an attack is still refused by
// the lint, which is where that decision belongs rather than in an accident of scope.
Vm constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

// The assertion family, at FILE scope. These decide nothing: the verdict is computed by
// the harness from balances the EVM reported, and no assertion an agent writes is
// consulted anywhere in it. They exist because an agent reaching for forge-std out of
// habit lost the whole attempt to `Undeclared identifier. Did you mean "assert"?` -- 54
// of those in one census, every one a recall loss with nothing wrong with the attack.
//
// They revert rather than no-op deliberately. The agent wrote them as control flow, and
// continuing silently past a failed check would run the rest of the attack in a state it
// did not intend. Reverting cannot manufacture a finding in either direction, because a
// reverted attack is measured as an attack that did nothing.
//
// File scope rather than a member of `Harness`, because a contract member shadows the
// whole overload set: a Harness declaring assertTrue(bool,string) makes assertTrue(cond)
// fail to resolve from inside it, and an Attacker -- which inherits nothing -- could not
// reach either. One set at file scope resolves identically everywhere.
//
// int256 overloads are deliberately absent: `assertEq(1, 2)` would then match both
// uint256 and int256 and fail with "No unique declaration found", trading one compile
// error for another.
function assertTrue(bool c) pure { require(c, "assertTrue"); }
function assertTrue(bool c, string memory why) pure { require(c, why); }
function assertFalse(bool c) pure { require(!c, "assertFalse"); }
function assertFalse(bool c, string memory why) pure { require(!c, why); }
function assertEq(uint256 a, uint256 b) pure { require(a == b, "assertEq"); }
function assertEq(uint256 a, uint256 b, string memory why) pure { require(a == b, why); }
function assertEq(address a, address b) pure { require(a == b, "assertEq"); }
function assertEq(address a, address b, string memory why) pure { require(a == b, why); }
function assertEq(bool a, bool b) pure { require(a == b, "assertEq"); }
function assertEq(bytes32 a, bytes32 b) pure { require(a == b, "assertEq"); }
function assertGt(uint256 a, uint256 b) pure { require(a > b, "assertGt"); }
function assertGt(uint256 a, uint256 b, string memory why) pure { require(a > b, why); }
function assertGe(uint256 a, uint256 b) pure { require(a >= b, "assertGe"); }
function assertLt(uint256 a, uint256 b) pure { require(a < b, "assertLt"); }
function assertLt(uint256 a, uint256 b, string memory why) pure { require(a < b, why); }
function assertLe(uint256 a, uint256 b) pure { require(a <= b, "assertLe"); }
function assertApproxEqAbs(uint256 a, uint256 b, uint256 d) pure {
    require(a > b ? a - b <= d : b - a <= d, "assertApproxEqAbs");
}

/// Inherit this in a PoC to get `vm`. The assertion family above is at file scope and
/// needs no inheritance at all.
/// The exploit template below is written by the harness, never by the auditor.
/// forge runs `test*` functions on contracts whose name starts with `Test`;
/// a function that reverts is a failing test, one that returns is a passing test.
contract Harness {

    /// Render a uint so the harness can tell the auditor HOW MUCH it fell short by.
    /// A bare "you did not profit" is a dead end; "you gained 1000000000000000000,
    /// honest gained 1000000000000000000" says the attack merely reproduced the
    /// intended behaviour, which points at what to change.
    function _u(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 n = v;
        uint256 digits;
        while (n != 0) { digits++; n /= 10; }
        bytes memory buf = new bytes(digits);
        while (v != 0) { digits--; buf[digits] = bytes1(uint8(48 + v % 10)); v /= 10; }
        return string(buf);
    }
}
