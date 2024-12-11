// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IPoolRouter} from "./interfaces/IPoolRouter.sol";
import {IAdapter} from "./interfaces/IAdapter.sol";

/// @title Pool Router
/// @notice Allows users to interact with various  liquidity pools
contract PoolRouter is IPoolRouter, Ownable2Step {
    using SafeERC20 for IERC20;

    /***********/
    /* Storage */
    /***********/

    /// @notice Total number of adapters
    uint256 public numAdapters;

    /// @notice Adapter ID => Adapter Info
    mapping(uint256 => AdapterInfo) private _adapters;

    /// @notice Adapter => AdapterStatus
    mapping(address => AdapterStatus) private _adapterStatuses;

    /*************/
    /* Modifiers */
    /*************/

    modifier validAdapter(uint256 _adapterId) {
        if (_adapterId >= numAdapters) {
            revert AdapterNotExist();
        }

        _;
    }

    /******************/
    /* User Functions */
    /******************/

    /// @inheritdoc IPoolRouter
    function getStakeInfo(
        address _account,
        uint256 _adapterId
    )
        external
        view
        validAdapter(_adapterId)
        returns (uint256, IAdapter.Reward[] memory)
    {
        AdapterInfo storage adapter = _adapters[_adapterId];
        return IAdapter(adapter.adapter).getStakeInfo(_account);
    }

    /// @inheritdoc IPoolRouter
    function stake(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external validAdapter(_adapterId) {
        AdapterInfo storage adapter = _adapters[_adapterId];
        Address.functionDelegateCall(
            adapter.adapter,
            abi.encodeWithSelector(IAdapter.stake.selector, _asset, _amount),
            "stake failed"
        );
    }

    /// @inheritdoc IPoolRouter
    function stakeETH(
        uint256 _adapterId
    ) external payable validAdapter(_adapterId) {
        AdapterInfo storage adapter = _adapters[_adapterId];
        Address.functionDelegateCall(
            adapter.adapter,
            abi.encodeWithSelector(IAdapter.stakeETH.selector),
            "stake failed"
        );
    }

    /// @inheritdoc IPoolRouter
    function stakeCallData(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    )
        external
        view
        validAdapter(_adapterId)
        returns (IAdapter.CallData[] memory)
    {
        AdapterInfo storage adapter = _adapters[_adapterId];
        return IAdapter(adapter.adapter).stakeCallData(_asset, _amount);
    }

    /// @inheritdoc IPoolRouter
    function unstake(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    ) external validAdapter(_adapterId) {
        AdapterInfo storage adapter = _adapters[_adapterId];
        Address.functionDelegateCall(
            adapter.adapter,
            abi.encodeWithSelector(IAdapter.unstake.selector, _asset, _amount),
            "unstake failed"
        );
    }

    /// @inheritdoc IPoolRouter
    function unstakeETH(
        uint256 _adapterId,
        uint256 _amount
    ) external validAdapter(_adapterId) {
        AdapterInfo storage adapter = _adapters[_adapterId];
        Address.functionDelegateCall(
            adapter.adapter,
            abi.encodeWithSelector(IAdapter.unstakeETH.selector, _amount),
            "unstake failed"
        );
    }

    /// @inheritdoc IPoolRouter
    function unstakeCallData(
        uint256 _adapterId,
        address _asset,
        uint256 _amount
    )
        external
        view
        validAdapter(_adapterId)
        returns (IAdapter.CallData[] memory)
    {
        AdapterInfo storage adapter = _adapters[_adapterId];
        return IAdapter(adapter.adapter).unstakeCallData(_asset, _amount);
    }

    /// @inheritdoc IPoolRouter
    function claimCallData(
        uint256 _adapterId
    )
        external
        view
        validAdapter(_adapterId)
        returns (IAdapter.CallData memory)
    {
        AdapterInfo storage adapter = _adapters[_adapterId];
        return IAdapter(adapter.adapter).claimCallData();
    }

    /*********************/
    /* Adapter Functions */
    /*********************/

    function getAdapterInfo(
        uint256 _adapterId
    ) external view returns (AdapterInfo memory) {
        return _adapters[_adapterId];
    }

    /// @inheritdoc IPoolRouter
    function addAdapter(
        address _adapter,
        string memory _protocol
    ) external onlyOwner {
        if (_adapter == address(0)) {
            revert ZeroAddress();
        }
        if (_adapterStatuses[_adapter] != AdapterStatus.NONE) {
            revert AdapterExist();
        }

        uint256 adapterIndex = numAdapters++;
        _adapters[adapterIndex] = AdapterInfo({
            adapter: _adapter,
            protocol: _protocol
        });
        _adapterStatuses[_adapter] = AdapterStatus.Active;

        emit AdapterAdded(adapterIndex, _adapter, _protocol);
    }
}
