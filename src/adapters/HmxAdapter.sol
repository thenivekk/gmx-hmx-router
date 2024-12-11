// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAdapter} from "../interfaces/IAdapter.sol";
import {ILiquidityHandler} from "../interfaces/hmx/ILiquidityHandler.sol";
import {IHLPStaking} from "../interfaces/hmx/IHLPStaking.sol";
import {IRewarder} from "../interfaces/hmx/IRewarder.sol";
import {ICompounder} from "../interfaces/hmx/ICompounder.sol";

/// @title HMX Adapter
/// @notice Adapter contract for the HMX protocol
contract HmxAdapter is IAdapter {
    using SafeERC20 for IERC20;

    /*************/
    /* Constants */
    /*************/

    /// @notice Used to mint HLP
    address public constant LIQUIDITY_HANDLER =
        0x1c6b1264B022dE3c6f2AddE01D11fFC654297ba6;

    /// @notice HLPStaking
    address public constant HLP_STAKING =
        0xbE8f8AF5953869222eA8D39F1Be9d03766010B1C;

    /// @notice Compounder
    address public constant COMPOUNDER =
        0x8E5D083BA7A46f13afccC27BFB7da372E9dFEF22;

    /// @notice HLP
    IERC20 public constant HLP =
        IERC20(0x4307fbDCD9Ec7AEA5a1c2958deCaa6f316952bAb);

    /// @notice Execution Fee : 0.0003 ETH
    uint256 public constant EXECUTION_FEE = 0.0003 ether;

    /**********************/
    /* Protocol Functions */
    /**********************/

    /// @inheritdoc IAdapter
    function getStakeInfo(
        address _account
    )
        external
        view
        returns (uint256 stakedAmount, Reward[] memory pendingRewards)
    {
        IHLPStaking staking = IHLPStaking(HLP_STAKING);

        stakedAmount = staking.userTokenAmount(_account);

        address[] memory rewarders = staking.getRewarders();
        uint256 length = rewarders.length;
        pendingRewards = new Reward[](length);
        for (uint256 i; i != length; ++i) {
            IRewarder rewarder = IRewarder(rewarders[i]);
            address rewardToken = rewarder.rewardToken();
            uint256 pendingReward = rewarder.pendingReward(_account);
            pendingRewards[i] = Reward({
                rewardToken: rewardToken,
                rewardAmount: pendingReward
            });
        }
    }

    /// @inheritdoc IAdapter
    function stake(
        address /* _asset */,
        uint256 /* _amount*/
    ) external pure returns (uint256) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function stakeETH() external payable returns (uint256) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function stakeCallData(
        address _asset,
        uint256 _amount
    ) external view returns (CallData[] memory data) {
        uint256 allowance = IERC20(_asset).allowance(
            msg.sender,
            LIQUIDITY_HANDLER
        );

        uint256 stakeCalldataIndex;

        if (allowance < _amount) {
            data = new CallData[](2);
            stakeCalldataIndex = 1;

            // approve calldata
            data[0] = CallData({
                to: _asset,
                value: 0,
                data: abi.encodeWithSelector(
                    IERC20.approve.selector,
                    LIQUIDITY_HANDLER,
                    type(uint256).max
                )
            });
        } else {
            data = new CallData[](1);
        }

        // stake calldata
        data[stakeCalldataIndex] = CallData({
            to: LIQUIDITY_HANDLER,
            value: EXECUTION_FEE,
            data: abi.encodeWithSelector(
                ILiquidityHandler.createAddLiquidityOrder.selector,
                _asset,
                _amount,
                0,
                EXECUTION_FEE,
                false,
                false
            )
        });
    }

    /// @inheritdoc IAdapter
    function unstake(
        address /* _asset */,
        uint256 /* _amount*/
    ) external pure returns (uint256) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function unstakeETH(uint256 /* _amount*/) external pure returns (uint256) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function unstakeCallData(
        address _asset,
        uint256 _amount
    ) external view returns (CallData[] memory data) {
        uint256 allowance = HLP.allowance(msg.sender, LIQUIDITY_HANDLER);
        uint256 length = allowance < _amount ? 3 : 2;
        data = new CallData[](length);

        // unstake calldata
        data[0] = CallData({
            to: HLP_STAKING,
            value: 0,
            data: abi.encodeWithSelector(IHLPStaking.withdraw.selector, _amount)
        });

        if (allowance < _amount) {
            // approve calldata
            data[1] = CallData({
                to: address(HLP),
                value: 0,
                data: abi.encodeWithSelector(
                    IERC20.approve.selector,
                    LIQUIDITY_HANDLER,
                    type(uint256).max
                )
            });
        }

        // HLP => asset sell calldata
        data[length - 1] = CallData({
            to: LIQUIDITY_HANDLER,
            value: EXECUTION_FEE,
            data: abi.encodeWithSelector(
                ILiquidityHandler.createRemoveLiquidityOrder.selector,
                _asset,
                _amount,
                0,
                EXECUTION_FEE,
                false
            )
        });
    }

    /// @inheritdoc IAdapter
    function claimCallData() external view returns (CallData memory data) {
        data.to = COMPOUNDER;

        address[] memory pools;
        pools = new address[](1);
        pools[0] = HLP_STAKING;

        IHLPStaking staking = IHLPStaking(HLP_STAKING);
        address[][] memory rewarders = new address[][](1);
        rewarders[0] = staking.getRewarders();

        data.data = abi.encodeWithSelector(
            ICompounder.compound.selector,
            pools,
            rewarders,
            0,
            0,
            new address[](0)
        );
    }
}
