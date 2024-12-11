// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Test} from "forge-std/Test.sol";
import {PoolRouter} from "../src/PoolRouter.sol";
import {GmxAdapter} from "../src/adapters/GmxAdapter.sol";
import {IAdapter} from "../src/interfaces/IAdapter.sol";

contract PoolRouterGmxTest is Test {
    PoolRouter public router;
    GmxAdapter public gmxAdapter;

    IERC20 public usdc;
    IERC20 public weth;
    IERC20 public sGLP;
    IERC20 public fsGLP;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        gmxAdapter = new GmxAdapter();
        router = new PoolRouter();

        usdc = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        weth = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        sGLP = IERC20(0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE);
        fsGLP = IERC20(0x1aDDD80E6039594eE970E5872D247bf0414C8903);

        router.addAdapter(address(gmxAdapter), "GMX");

        // mints 10,000 USDC to user
        deal(address(usdc), user, 10000e6);
        // give 10 ETH to user
        deal(user, 10e18);
    }

    function test_stake_usdc_fail_with_InsufficientBalance() public {
        vm.startPrank(user);

        uint256 amount = usdc.balanceOf(user) + 1;
        usdc.approve(address(router), amount);

        vm.expectRevert(bytes("ERC20: transfer amount exceeds balance"));
        router.stake(0, address(usdc), amount);

        vm.stopPrank();
    }

    function test_stake_usdc_fail_with_InsufficientAllowance() public {
        vm.startPrank(user);

        uint256 amount = 100e6; // 100 USDC
        usdc.approve(address(router), 0);

        vm.expectRevert(bytes("ERC20: transfer amount exceeds allowance"));
        router.stake(0, address(usdc), amount);

        vm.stopPrank();
    }

    function test_stake_usdc_success() public {
        vm.startPrank(user);

        uint256 amount = 100e6; // 100 USDC
        usdc.approve(address(router), amount);

        uint256 beforeBalance = fsGLP.balanceOf(user);
        router.stake(0, address(usdc), amount);
        uint256 afterBalance = fsGLP.balanceOf(user);
        assertGt(afterBalance, beforeBalance);

        vm.stopPrank();
    }

    function test_stakeETH_success() public {
        vm.startPrank(user);

        uint256 amount = 2e18; // 2 ETH

        uint256 beforeBalance = fsGLP.balanceOf(user);
        router.stakeETH{value: amount}(0);
        uint256 afterBalance = fsGLP.balanceOf(user);
        assertGt(afterBalance, beforeBalance);

        vm.stopPrank();
    }

    function test_unstake_usdc_success() public {
        vm.startPrank(user);

        router.stakeETH{value: 2e18}(0);

        uint256 balance = fsGLP.balanceOf(user);
        sGLP.approve(address(router), balance);

        uint256 beforeBalance = usdc.balanceOf(user);
        router.unstake(0, address(usdc), balance);
        assertEq(fsGLP.balanceOf(user), 0);
        uint256 afterBalance = usdc.balanceOf(user);
        assertGt(afterBalance, beforeBalance);

        vm.stopPrank();
    }

    function test_unstakeETH_success() public {
        vm.startPrank(user);

        router.stakeETH{value: 2e18}(0);

        uint256 balance = fsGLP.balanceOf(user);
        sGLP.approve(address(router), balance);

        uint256 beforeBalance = user.balance;
        router.unstakeETH(0, balance);
        assertEq(fsGLP.balanceOf(user), 0);
        uint256 afterBalance = user.balance;
        assertGt(afterBalance, beforeBalance);

        vm.stopPrank();
    }

    function test_getStakeInfo() public {
        vm.startPrank(user);

        (uint256 stakedAmount, IAdapter.Reward[] memory pendingRewards) = router
            .getStakeInfo(user, 0);
        assertEq(stakedAmount, 0);
        assertEq(pendingRewards.length, 1);
        assertEq(pendingRewards[0].rewardToken, WETH);
        assertEq(pendingRewards[0].rewardAmount, 0);

        router.stakeETH{value: 2e18}(0);

        skip(10 days);

        (stakedAmount, pendingRewards) = router.getStakeInfo(user, 0);
        assertGt(stakedAmount, 0);
        assertEq(pendingRewards.length, 1);
        assertEq(pendingRewards[0].rewardToken, WETH);
        assertGt(pendingRewards[0].rewardAmount, 0);

        vm.stopPrank();
    }

    function test_claim_success() public {
        vm.startPrank(user);

        router.stakeETH{value: 2e18}(0);

        skip(10 days);

        uint256 beforeBalance = weth.balanceOf(user);
        IAdapter.CallData memory data = router.claimCallData(0);
        (bool success, ) = data.to.call{value: data.value}(data.data);
        assertEq(success, true);
        uint256 afterBalance = weth.balanceOf(user);
        assertGt(afterBalance, beforeBalance);

        vm.stopPrank();
    }
}
