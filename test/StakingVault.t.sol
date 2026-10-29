// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/StakingVault.sol";

/// An ordinary depositor: stakes, waits for nothing, takes the stake back.
contract HonestUser {
    receive() external payable {}

    function stake(StakingVault vault) external payable {
        vault.stake{value: msg.value}();
    }

    function unstake(StakingVault vault) external {
        vault.unstake();
    }
}

/// The honest path, with no attacker anywhere: every depositor gets back exactly what
/// they put in, and the vault keeps everyone else's money. ARBITER Gate's patch check
/// (P6, check 4) runs the repository's own tests like this one against a patch.
contract StakingVaultHonestTest {
    StakingVault vault;

    function setUp() public {
        vault = new StakingVault{value: 5 ether}();
    }

    function test_honest_user_gets_stake_back() public {
        HonestUser alice = new HonestUser();
        alice.stake{value: 2 ether}(vault);
        require(vault.stakeOf(address(alice)) == 2 ether, "stake not recorded");

        alice.unstake(vault);
        require(address(alice).balance == 2 ether, "alice did not get her 2 ether back");
        require(vault.stakeOf(address(alice)) == 0, "position not cleared");
        require(address(vault).balance == 5 ether, "the vault lost other people's money");
        require(vault.totalStaked() == 5 ether, "totalStaked out of step");
    }

    function test_two_users_each_get_their_own_stake_back() public {
        HonestUser alice = new HonestUser();
        HonestUser bob = new HonestUser();
        alice.stake{value: 2 ether}(vault);
        bob.stake{value: 3 ether}(vault);

        bob.unstake(vault);
        alice.unstake(vault);
        require(address(alice).balance == 2 ether, "alice short");
        require(address(bob).balance == 3 ether, "bob short");
        require(address(vault).balance == 5 ether, "the vault lost other people's money");
    }

    function test_unstake_without_position_reverts() public {
        (bool ok, ) = address(vault).call(abi.encodeWithSignature("unstake()"));
        require(!ok, "unstake with no position should revert");
    }
}
