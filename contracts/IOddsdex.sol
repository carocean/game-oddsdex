// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;

//内部发动机自行运转，捫、开、撮、捫、开、撮……
//输赢：合约每次生成的随机数+所有玩家的幸运数 -> %2
interface IOddsdexContract {
    function getState() external returns (OddsdexState);

    function getWinningDirection() external returns (CoinDirection);

    function getWeiPrice() external returns (uint256);

    function getBulletinBoard() external returns (BulletinBoard memory);

    function canMatchmaking() external returns (bool);

    function isRunning() external returns (bool);

    function stop() external;

    function run() external;

    function getRoot() external returns (address);

    function getBroker() external returns (address);

    function oddBalanceOf(address _player) external returns (uint256);

    function cover(uint256 _hash) external;

    function lottery(uint256 _luckyNumber) external returns (CoinDirection);

    function matchmake() external;

    function stake(
        CoinDirection buyDirection,
        uint32 luckyNumber
    ) external payable;

    event OnLotteryEvent(LotteryMessage message);

    event OnMatchMakingEvent(MatchmakingBill bill);
    event OnStakeBillEvent(StakeBill bill);
    event OnReturnBillEvent(ReturnBill bill);
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
    uint256 price;
    uint256 odds;
    uint16 kickbackRate;
    uint16 brokerageRate;
    uint16 taxRate;
}
struct StakeBill {
    string id;
    address owner;
    uint256 odds;
    uint256 costs;
    uint256 buyPrice;
    CoinDirection buyDirection;
    uint256 gas;
    uint32 luckyNumber;
}
struct MatchmakingBill {
    string id;
    string refFId;
    string refBId;
    string mtn; //Matchmaking transaction number
    address broker;
    uint256 dealOdds;
    uint256 dealPrice;
    uint256 tailFOdds;
    uint256 tailBOdds;
    uint256 tailFCostOnBill;
    uint256 tailBCostOnBill;
    uint256 tailFReturnCosts;
    uint256 tailBReturnCosts;
    uint256 prize;
}
struct ReturnBill {
    string id;
    string refId;
    string mtn; //Matchmaking transaction number
    address owner;
    uint256 costs;
}
struct SplitBill {
    string id;
    string refId;
    string mtn; //Matchmaking transaction number
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
