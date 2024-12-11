// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAdapter {
    /**********/
    /* Struct */
    /**********/

    struct Reward {
        address rewardToken;
        uint256 rewardAmount;
    }

    struct CallData {
        address to;
        uint256 value;
        bytes data;
    }

    /**********/
    /* Errors */
    /**********/

    /// @notice Zero Address Error
    error ZeroAddress();

    /**********************/
    /* Protocol Functions */
    /**********************/

    /// @notice Get user's stake info
    /// @param _account User address
    /// @return stakedAmount Staked amount
    /// @return pendingRewards Pending reward amount
    function getStakeInfo(
        address _account
    )
        external
        view
        returns (uint256 stakedAmount, Reward[] memory pendingRewards);

    /// @notice Stake asset into the protocol
    /// @param _asset Stake asset
    /// @param _amount Stake amount
    /// @return lpAmount LP token amount minted
    function stake(
        address _asset,
        uint256 _amount
    ) external returns (uint256 lpAmount);

    /// @notice Stake ETH into the protocol
    /// @return lpAmount LP token amount minted
    function stakeETH() external payable returns (uint256 lpAmount);

    /// @notice Return calldata to stake asset
    function stakeCallData(
        address _asset,
        uint256 _amount
    ) external view returns (CallData[] memory);

    /// @notice Unstake asset from the protocol
    /// @param _asset Unstake asset
    /// @param _amount LP token amount to burn
    /// @return amount Amount unstaked
    function unstake(
        address _asset,
        uint256 _amount
    ) external returns (uint256 amount);

    /// @notice Unstake ETH from the protocol
    /// @param _amount LP token amount to burn
    /// @return amount ETH unstaked
    function unstakeETH(uint256 _amount) external returns (uint256 amount);

    /// @notice Return calldata to unstake asset
    function unstakeCallData(
        address _asset,
        uint256 _amount
    ) external view returns (CallData[] memory);

    /// @notice Return calldata to claim rewards
    function claimCallData() external view returns (CallData memory);
}
