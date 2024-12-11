// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHLPStaking {
    function userTokenAmount(address) external view returns (uint256);

    function getRewarders() external view returns (address[] memory);

    function withdraw(uint256) external;
}
