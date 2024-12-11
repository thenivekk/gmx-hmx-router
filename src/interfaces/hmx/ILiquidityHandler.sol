// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidityHandler {
    enum LiquidityOrderStatus {
        PENDING,
        SUCCESS,
        FAIL
    }

    struct LiquidityOrder {
        uint256 orderId;
        uint256 amount;
        uint256 minOut;
        uint256 actualAmountOut;
        uint256 executionFee;
        address payable account;
        uint48 createdTimestamp;
        uint48 executedTimestamp;
        address token;
        bool isAdd;
        bool isNativeOut; // token Out for remove liquidity(!unwrap) and refund addLiquidity (shouldWrap) flag
        LiquidityOrderStatus status;
    }

    function createAddLiquidityOrder(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _executionFee,
        bool _shouldWrap,
        bool _isSurge
    ) external payable returns (uint256 _orderId);

    function createRemoveLiquidityOrder(
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _executionFee,
        bool _isNativeOut
    ) external payable returns (uint256 _orderId);

    function executeOrder(
        uint256 _endIndex,
        address payable _feeReceiver,
        bytes32[] calldata _priceData,
        bytes32[] calldata _publishTimeData,
        uint256 _minPublishTime,
        bytes32 _encodedVaas
    ) external;

    function accountExecutedLiquidityOrders(
        address,
        uint256
    ) external view returns (LiquidityOrder memory);
}
