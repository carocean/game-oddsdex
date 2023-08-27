// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;

//内部发动机自行运转，捫、开、撮、捫、开、撮……
//输赢：合约每次生成的随机数+所有玩家的幸运数 -> %2
interface IOddsdexContract {
    function getState() external returns (OddsdexState);

    function getWinningDirection() external returns (CoinDirection);

    function getWeiPrice() external returns (uint256);

    function getBulletinBoard() external returns (BulletinBoard memory);

    function isRunning() external returns (bool);

    function stop() external;

    function run() external;

    function getRoot() external returns (address);

    function getBroker() external returns (address);

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

    function cover(uint256 _hash) external;

    function stake(
        uint256 buyPrice,
        CoinDirection buyDirection,
        uint32 luckyNumber
    ) external payable;

    event OnLotteryEvent(LotteryMessage message);

    event OnMatchMakingEvent(MatchmakingBill bill);
    event OnStakeBillEvent(StakeBill bill);
    event OnRefundBillEvent(RefundBill bill);
    event OnSplitBillEvent(SplitBill bill);
}
struct LotteryMessage {
    CoinDirection winningDirection;
    uint256 luckyNumber;
    address broker;
    uint256 coverHash;
}
enum CoinDirection {
    unknown,
    front,
    back
}
enum OddsdexState {
    covering,
    lottering,
    lottered,
    matchmaking,
    matchmaked
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
struct StakeBill {
    bytes32 id;
    address owner;
    uint256 odds;
    uint256 costs;
    uint256 buyPrice;
    uint256 marketPrice;
    CoinDirection buyDirection;
    uint256 gas;
    uint32 luckyNumber;
}
struct MatchmakingBill {
    bytes32 id;
    bytes32 refFId;
    bytes32 refBId;
    bytes32 mtn; //Matchmaking transaction number
    address broker;
    uint256 dealOdds;
    uint256 dealPrice;
    uint256 tailFOdds;
    uint256 tailBOdds;
    uint256 tailFCostOnBill;
    uint256 tailBCostOnBill;
    uint256 tailFRefundCosts;
    uint256 tailBRefundCosts;
    uint256 prize;
}
struct RefundBill {
    bytes32 id;
    bytes32 refId;
    bytes32 mtn; //Matchmaking transaction number
    address owner;
    uint256 costs;
}
struct SplitBill {
    bytes32 id;
    bytes32 refId;
    bytes32 mtn; //Matchmaking transaction number
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
