// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;

interface IGamblingContractFactory {
    function createOddsdexContract(
        address _broker
    ) external returns (address);

    function getBrokerCount() external returns (uint256);

    function getOddsdexCount() external returns (uint256);

    function enumBroker() external returns (address[] memory);

    function setAnnualFee(uint256 annualFee) external;

    function setMonthlyFee(uint256 monthlyFee) external;

    function getApplyRights(
        address broker
    ) external returns (ApplyRights memory);

    function isPaidOfBroker(address broker) external returns (bool);

    function isValidBroker(address broker) external returns (bool);

    function isExpired(address broker) external returns (bool, uint8);

    function getBalance() external returns (uint256);

    function getAddress() external returns (address);

    function getAnnualFee() external returns (uint256);

    function getMonthlyFee() external returns (uint256);

    function listContractOfBroker(
        address broker
    ) external returns (address[] memory);

    function withdraw() external payable;

    function recMothlyFee() external payable;

    event OnCreateOddsdexContract(CreateOddsdexContractMessage e);
}

struct CreateOddsdexContractMessage {
    address contractAddress;
    address root;
    address broker;
    ApplyRights rights;
}

struct ApplyRights {
    bool isAllow;
    uint8 payMode; //1:annualFee;2:monthlyFee
    uint time;
}
