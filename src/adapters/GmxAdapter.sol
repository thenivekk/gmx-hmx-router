// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IAdapter} from "../interfaces/IAdapter.sol";
import {IRewardRouterV2} from "../interfaces/gmx/IRewardRouterV2.sol";
import {IRewardTracker} from "../interfaces/gmx/IRewardTracker.sol";

/// @title GMX Adapter
/// @notice Adapter contract for the GMX protocol
contract GmxAdapter is IAdapter {
    using SafeERC20 for IERC20;

    /*************/
    /* Constants */
    /*************/

    /// @notice Used to claim GLP fees
    address public constant REWARD_ROUTER =
        0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;

    /// @notice Used to mint/redeem GLP
    address public constant GLP_REWARD_ROUTER =
        0xB95DB5B167D75e6d04227CfFFA61069348d271F5;

    /// @notice Used to approve tokens to mint GLP
    address public constant GLP_MANAGER =
        0x3963FfC9dff443c2A94f21b129D429891E32ec18;

    /// @notice fGLP
    IRewardTracker public constant fGLP =
        IRewardTracker(0x4e971a87900b931fF39d1Aad67697F49835400b6);

    /// @notice sGLP
    IERC20 public constant sGLP =
        IERC20(0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE);

    /// @notice fsGLP
    IERC20 public constant fsGLP =
        IERC20(0x1aDDD80E6039594eE970E5872D247bf0414C8903);

    /// @notice WETH
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

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
        stakedAmount = fsGLP.balanceOf(_account);
        pendingRewards = new Reward[](1);
        pendingRewards[0] = Reward({
            rewardToken: WETH,
            rewardAmount: IRewardTracker(fGLP).claimable(_account)
        });
    }

    /// @inheritdoc IAdapter
    function stake(
        address _asset,
        uint256 _amount
    ) external returns (uint256 lpAmount) {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(GLP_REWARD_ROUTER);

        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);

        IERC20(_asset).safeIncreaseAllowance(GLP_MANAGER, _amount);

        lpAmount = rewardRouter.mintAndStakeGlp(_asset, _amount, 0, 0);

        sGLP.safeTransfer(msg.sender, lpAmount);
    }

    /// @inheritdoc IAdapter
    function stakeETH() external payable returns (uint256 lpAmount) {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(GLP_REWARD_ROUTER);

        lpAmount = rewardRouter.mintAndStakeGlpETH{value: msg.value}(0, 0);

        sGLP.safeTransfer(msg.sender, lpAmount);
    }

    /// @inheritdoc IAdapter
    function stakeCallData(
        address /* _asset */,
        uint256 /* _amount */
    ) external pure returns (CallData[] memory) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function unstake(
        address _asset,
        uint256 _amount
    ) external returns (uint256 amount) {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(GLP_REWARD_ROUTER);

        sGLP.safeTransferFrom(msg.sender, address(this), _amount);

        amount = rewardRouter.unstakeAndRedeemGlp(
            _asset,
            _amount,
            0,
            msg.sender
        );
    }

    /// @inheritdoc IAdapter
    function unstakeETH(uint256 _amount) external returns (uint256 amount) {
        IRewardRouterV2 rewardRouter = IRewardRouterV2(GLP_REWARD_ROUTER);

        sGLP.safeTransferFrom(msg.sender, address(this), _amount);

        amount = rewardRouter.unstakeAndRedeemGlpETH(
            _amount,
            0,
            payable(msg.sender)
        );
    }

    /// @inheritdoc IAdapter
    function unstakeCallData(
        address /* _asset */,
        uint256 /* _amount */
    ) external pure returns (CallData[] memory) {
        revert("not supported");
    }

    /// @inheritdoc IAdapter
    function claimCallData() external pure returns (CallData memory data) {
        data.to = REWARD_ROUTER;
        data.data = abi.encodeWithSelector(IRewardRouterV2.claimFees.selector);
    }
}
