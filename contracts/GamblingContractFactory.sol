// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;
import "./IGamblingContractFactory.sol";
import "./OddsdexContract.sol";
import "./SafeMath.sol";

contract GamblingContractFactory is IGamblingContractFactory {
    using SafeMath for *;

    address public root;
    address[] public contracts;
    mapping(address => address[]) public contractsOfBroker;
    address[] public brokers;
    mapping(address => ApplyRights) private rights;
    uint256 private annualFee = 4200000000000000000; //4.2 ether
    uint256 private monthlyFee = 400000000000000000; //0.4 ether

    constructor() {
        root = msg.sender;
    }

    modifier onlyRoot() {
        require(root == msg.sender, "Only root can call this.");
        _;
    }

    function getApplyRights(
        address broker
    ) public view override returns (ApplyRights memory) {
        return rights[broker];
    }

    function isPaidOfBroker(
        address broker
    ) public view override returns (bool) {
        ApplyRights memory right = rights[broker];
        return right.time != 0;
    }

    function isValidBroker(address broker) public view override returns (bool) {
        ApplyRights memory right = rights[broker];
        if (!right.isAllow) {
            return false;
        }
        if (right.time == 0) {
            return false;
        }
        (bool expired, ) = isExpired(broker);
        return !expired;
    }

    function isExpired(
        address broker
    ) public view override returns (bool, uint8) {
        ApplyRights memory right = rights[broker];

        bool _expired;
        uint8 payMode = right.payMode;
        if (right.time == 0) {
            return (true, payMode);
        }
        if (payMode == 1) {
            _expired = (block.timestamp - right.time >= 31536000);
        }
        if (payMode == 2) {
            _expired = (block.timestamp - right.time >= 2678400);
        }
        return (_expired, payMode);
    }

    function getBalance() public view override returns (uint256) {
        return address(this).balance;
    }

    function getAddress() public view override returns (address) {
        return address(this);
    }

    function getAnnualFee() public view override returns (uint256) {
        return annualFee;
    }

    function getMonthlyFee() public view override returns (uint256) {
        return monthlyFee;
    }

    function setAnnualFee(uint256 _annualFee) public override onlyRoot {
        require(_annualFee > 0, "Annual fee cannot be negative");
        annualFee = _annualFee;
    }

    function setMonthlyFee(uint256 _monthlyFee) public override onlyRoot {
        require(_monthlyFee > 0, "Monthly fee cannot be negative");
        monthlyFee = _monthlyFee;
    }

    function createOddsdexContract(
        address _broker
    ) public override onlyRoot returns (address) {
        require(
            isValidBroker(_broker),
            "Access to blind boxes is not allowed and must be paid or expired"
        );

        OddsdexContract blindBox = new OddsdexContract(root, _broker);
        address blindBoxAddress = address(blindBox);
        contracts.push(blindBoxAddress);
        address[] storage contractAddressArr = contractsOfBroker[_broker];
        contractAddressArr.push(blindBoxAddress);
        bool foundKey = false;
        for (uint i = 0; i < brokers.length; i++) {
            if (brokers[i] == _broker) {
                foundKey = true;
                break;
            }
        }
        if (!foundKey) {
            brokers.push(_broker);
        }
        CreateOddsdexContractMessage memory cgcm = CreateOddsdexContractMessage(
            blindBoxAddress,
            msg.sender,
            _broker,
            rights[_broker]
        );

        emit OnCreateOddsdexContract(cgcm);
        return blindBoxAddress;
    }

    function withdraw() public payable override onlyRoot {
        (bool success, ) = payable(root).call{value: address(this).balance}(
            new bytes(0)
        );
        require(success, "ETH_TRANSFER_FAILED");
    }

    fallback() external payable {
        require(false, "No other calls supported");
    }

    ///@dev The default payment method is only used for charging annual fees
    receive() external payable {
        require(
            msg.value >= annualFee,
            "The fee should be at least equal to the annual fee"
        );
        rights[msg.sender] = ApplyRights(true, 1, block.timestamp);
    }

    function recMothlyFee() external payable override {
        require(
            msg.value >= monthlyFee,
            "The fee should be at least equal to the monthly fee"
        );
        rights[msg.sender] = ApplyRights(true, 2, block.timestamp);
    }

    function getBrokerCount() public view override returns (uint256) {
        return brokers.length;
    }

    function getOddsdexCount() public view override returns (uint256) {
        return contracts.length;
    }

    function enumBroker() public view override returns (address[] memory) {
        return brokers;
    }

    function listContractOfBroker(
        address broker
    ) public view override returns (address[] memory) {
        return contractsOfBroker[broker];
    }
}
