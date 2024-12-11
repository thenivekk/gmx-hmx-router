// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAdapter} from "./IAdapter.sol";

interface IPoolRouter {
    enum AdapterStatus {
        NONE,
        Active
    }

    struct AdapterInfo {
        address adapter;
        string protocol;
    }

    /**********/
    /* Events */
    /**********/

    /// @notice Emitted when new adapter is added
    event AdapterAdded(
        uint256 indexed adapterIndex,
        address indexed adapter,
        string protocol
    );

    /**********/
    /* Errors */
    /**********/

    /// @notice Adapter already exist
    error AdapterExist();

    /// @notice Adapter doe not exist
    error AdapterNotExist();

    /// @notice Invalid amount error
    error InvalidAmount();

    /// @notice Zero address error
    error ZeroAddress();

    /// @notice Zero amount error
    error ZeroAmount();

    /******************/
    /* User Functions */
    /******************/

    /// @notice Get user's stake info
    /// @param _account User address
    /// @param _adapterId Adapter ID
    function getStakeInfo(
        address _account,
        uint256 _adapterId
    )
        external
        view
        returns (uint256 stakedAmount, IAdapter.Reward[] memory pendingRewards);

    /// @notice Stake asset into the adapter
    /// @param _adapterId Adapter ID
    /// @param _asset Stake asset
    /// @param _amount Stake amount
    function stake(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external;

    /// @notice Stake ETH into the adapter
    /// @param _adapterId Adapter ID
    function stakeETH(uint256 _adapterId) external payable;

    /// @notice Return calldata to stake asset
    function stakeCallData(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external view returns (IAdapter.CallData[] memory);

    /// @notice Unstake asset from the adapter
    /// @param _adapterId Adapter ID
    /// @param _asset Unstake asset
    /// @param _amount Unstake amount
    function unstake(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external;

    /// @notice Unstake ETH from the adapter
    /// @param _adapterId Adapter ID
    /// @param _amount Unstake amount
    function unstakeETH(uint256 _adapterId, uint256 _amount) external;

    /// @notice Return calldata to unstake asset
    function unstakeCallData(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external view returns (IAdapter.CallData[] memory);

    /// @notice Return calldata to claim rewards
    function claimCallData(
        uint256 _adapterId
    ) external view returns (IAdapter.CallData memory);

    /*********************/
    /* Adapter Functions */
    /*********************/

    /// @notice Return adapter info
    function getAdapterInfo(
        uint256 _adapterId
    ) external view returns (AdapterInfo memory);

    /// @notice Add new adapter
    /// @dev Only owner can add new adapter
    /// @param _adapter Adapter address
    /// @param _protocol Protocol name
    function addAdapter(address _adapter, string memory _protocol) external;
}
