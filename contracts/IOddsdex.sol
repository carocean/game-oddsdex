// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;

interface IOddsdexContract {
    function getWeiPrice() external returns (uint256);

    function getBulletinBoard() external returns (BulletinBoard memory);

    function isRunning() external returns (bool);

    function stop() external;

    function run() external;

    function getRoot() external returns (address);

    function getBroker() external returns (address);

    function getBalance() external returns (uint256);

    function getStakeBill(
        uint32 index
    ) external returns (bool exists, StakeBill memory bill);

    function getQueueCount() external returns (uint256);

    function getFrontQueueCount() external returns (uint256);

    function getBackQueueCount() external returns (uint256);

    function getFirstBillOfFrontQueue()
        external
        returns (uint32 bitIndexAt, StakeBill memory bill);

    function getFirstBillOfBackQueue()
        external
        returns (uint32 bitIndexAt, StakeBill memory bill);

    function getTopFiveBillFrontQueue()
        external
        returns (uint32 length, StakeBill[5] memory bills);

    function getTopFiveBillBackQueue()
        external
        returns (uint32 length, StakeBill[5] memory bills);

    function recharge() external payable;

    function canMatchmaking()
        external
        returns (bool matched, MatchmakingResult memory result);

    function matchmake() external;

    function stake(
        uint256 buyPrice,
        CoinDirection buyDirection,
        uint32 luckyNumber
    ) external payable;

    event OnMatchmakeReturn(
        uint32 matchmakeTimes,
        CoinDirection winningDirection
    );
    event OnRechargeEvent(RechargeBill bill);
    event OnStakeBillEvent(StakeBill bill);
    event OnMatchMakingEvent(MatchmakingBill bill);
    event OnRefundBillEvent(RefundBill bill);
    event OnSplitBillEvent(SplitBill bill);
}

enum CoinDirection {
    unknown,
    front,
    back
}

struct BulletinBoard {
    uint256 oddunit;
    uint256 price; //The price is defined by multiplying the actual price by 100, which means the actual price supports two decimal places
    uint256 odds;
    uint256 funds;
    uint16 kickbackRate;
    uint16 brokerageRate;
    uint16 taxRate;
}
struct MatchmakingResult {
    uint32 bitIndexAtF;
    StakeBill tailF;
    uint32 bitIndexAtB;
    StakeBill tailB;
}
struct LuckyNumber {
    uint8 r1;
    uint8 r2;
    uint8 r3;
    uint8 r4;
    uint8 r5;
    uint8 f;
    uint8 b;
    uint256 sign;
}
//rc-
struct RechargeBill {
    bytes16 id;
    address broker;
    uint256 amount;
    uint256 balance;
    uint256 gas;
}
//sk-
struct StakeBill {
    bytes16 id;
    address owner;
    uint256 odds;
    uint256 costs;
    uint256 buyPrice;
    uint256 marketPrice;
    CoinDirection buyDirection;
    uint256 gas;
    uint32 luckyNumber;
}
//mm-
struct MatchmakingBill {
    bytes16 id;
    bytes16 fid;
    bytes16 bid;
    address broker;
    uint256 dealOdds;
    uint256 dealPrice;
    uint256 fOdds;
    uint256 bOdds;
    uint256 fCostOnBill;
    uint256 bCostOnBill;
    uint256 fRefundCosts;
    uint256 bRefundCosts;
    uint256 prize;
    CoinDirection winningDirection;
}
//rf-
struct RefundBill {
    bytes16 id;
    bytes16 mmid;
    address owner;
    uint256 costs;
}
//st-
struct SplitBill {
    bytes16 id;
    bytes16 mmid;
    address owner;
    uint16 kickbackRate;
    uint16 brokerageRate;
    uint16 taxRate;
    uint256 prize;
    uint256 bonus;
    uint256 kickback;
    uint256 brokerage;
    uint256 tax;
}
