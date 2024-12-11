// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Test} from "forge-std/Test.sol";
import {PoolRouter} from "../src/PoolRouter.sol";
import {HmxAdapter} from "../src/adapters/HmxAdapter.sol";
import {IAdapter} from "../src/interfaces/IAdapter.sol";
import {ILiquidityHandler} from "../src/interfaces/hmx/ILiquidityHandler.sol";

contract PoolRouterHmxTest is Test {
    PoolRouter public router;
    HmxAdapter public hmxAdapter;

    ILiquidityHandler public liquidityHandler;

    IERC20 public usdc;
    IERC20 public arb;

    address public owner = makeAddr("owner");
    address public nonOwner = makeAddr("nonOwner");
    address public user = makeAddr("user");
    address public executor = 0xF1235511e36f2F4D578555218c41fe1B1B5dcc1E;

    bytes32 public constant encodedVaas =
        0xfde05bf822ecd97aaf7c323e4814679f353c2785a95d336949796b7dac587578;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        hmxAdapter = new HmxAdapter();
        router = new PoolRouter();

        liquidityHandler = ILiquidityHandler(
            0x1c6b1264B022dE3c6f2AddE01D11fFC654297ba6
        );

        usdc = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
        arb = IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);

        router.addAdapter(address(hmxAdapter), "HMX");

        // mints 10,000 USDC to user
        deal(address(usdc), user, 10000e6);
        // give 10 ETH to user
        deal(user, 10e18);
    }

    function getPriceData() internal pure returns (bytes32[] memory priceData) {
        priceData = new bytes32[](5);
        priceData[
            0
        ] = 0x012e7901a1b0ffffff000001fffffe00cdad00c30201295100c2ec00e7460000;
        priceData[
            1
        ] = 0x00d5e40002f9007c8300064effef8e000902ffde6bfff862ffeeec0003d20000;
        priceData[
            2
        ] = 0x00178200a83900c11c00bed800d4bc00a27700e8ccffed6200effb006c290000;
        priceData[
            3
        ] = 0xfffac7ffa3ee000bf9000b740133e8004cf100505700d80aff85fd0008e60000;
        priceData[
            4
        ] = 0x000491005bc700b4000000000000000000000000000000000000000000000000;
    }

    function getPublishTimeData()
        internal
        pure
        returns (bytes32[] memory publishTimeData)
    {
        publishTimeData = new bytes32[](5);
        publishTimeData[
            0
        ] = 0x0030a20030a20030a20030a20030a20000030030a20030a20000030000070000;
        publishTimeData[
            1
        ] = 0x0000030030a10030a20030a40030a20030a20030a20030a20030a20030a20000;
        publishTimeData[
            2
        ] = 0x0030a20030a20000020000030030a20030a20000260030a20000000030a20000;
        publishTimeData[
            3
        ] = 0x0030a10030a20030a20030a20030a40030a20030a10030a20030a20030a40000;
        publishTimeData[
            4
        ] = 0x0030a40030a20030a40000000000000000000000000000000000000000000000;
    }

    function executeOrder() internal {
        vm.prank(executor);
        liquidityHandler.executeOrder(
            type(uint256).max,
            payable(executor),
            getPriceData(),
            getPublishTimeData(),
            0,
            encodedVaas
        );
    }

    function test_fullFlow() public {
        vm.startPrank(user);

        (uint256 stakedAmount, IAdapter.Reward[] memory pendingRewards) = router
            .getStakeInfo(user, 0);
        assertEq(stakedAmount, 0);
        assertEq(pendingRewards.length, 4);
        assertEq(pendingRewards[0].rewardAmount, 0);
        assertEq(pendingRewards[1].rewardAmount, 0);
        assertEq(pendingRewards[2].rewardAmount, 0);
        assertEq(pendingRewards[3].rewardAmount, 0);

        // stake test
        uint256 amount = 100e6; // 100 USDC
        IAdapter.CallData[] memory datas = router.stakeCallData(
            0,
            address(usdc),
            amount
        );
        for (uint256 i; i != datas.length; ++i) {
            Address.functionCallWithValue(
                datas[i].to,
                datas[i].data,
                datas[i].value,
                "stake failed"
            );
        }

        vm.stopPrank();

        executeOrder();

        skip(10 days);

        // getStakeInfo test
        vm.startPrank(user);
        (stakedAmount, pendingRewards) = router.getStakeInfo(user, 0);
        assertGt(stakedAmount, 0);
        assertEq(pendingRewards.length, 4);

        assertGt(pendingRewards[0].rewardAmount, 0);
        assertEq(pendingRewards[1].rewardAmount, 0);
        assertGt(pendingRewards[2].rewardAmount, 0);
        assertGt(pendingRewards[3].rewardAmount, 0);

        // claim test
        uint256 beforeUsdcBalance = usdc.balanceOf(user);
        uint256 beforeArbBalance = arb.balanceOf(user);

        IAdapter.CallData memory data = router.claimCallData(0);
        Address.functionCallWithValue(
            data.to,
            data.data,
            data.value
        );

        uint256 afterUsdcBalance = usdc.balanceOf(user);
        uint256 afterArbBalance = arb.balanceOf(user);

        assertGt(afterUsdcBalance, beforeUsdcBalance);
        assertGt(afterArbBalance, beforeArbBalance);

        // unstake test
        beforeUsdcBalance = usdc.balanceOf(user);

        datas = router.unstakeCallData(0, address(usdc), stakedAmount);
        for (uint256 i; i != datas.length; ++i) {
            Address.functionCallWithValue(
                datas[i].to,
                datas[i].data,
                datas[i].value,
                "unstake failed"
            );
        }

        vm.stopPrank();

        executeOrder();

        afterUsdcBalance = usdc.balanceOf(user);
        assertGt(afterUsdcBalance, beforeUsdcBalance);

        (stakedAmount, ) = router.getStakeInfo(user, 0);
        assertEq(stakedAmount, 0);
    }
}
