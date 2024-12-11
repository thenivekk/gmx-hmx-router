// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRewardTracker {
    function claimable(address _account) external view returns (uint256);
}
