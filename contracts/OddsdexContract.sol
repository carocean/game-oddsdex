// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;
import "./IOddsdexContract.sol";
import "./SafeMath.sol";

contract OddsdexContract is IOddsdexContract {
    using SafeMath for *;

    OddsdexState private state;
    bool private running;
    address private root;
    address private broker;
    address private parent;
    BulletinBoard private bulletinBoard;
    uint256 private coverHash;
    CoinDirection private winningDirection;
    mapping(address => PlayerBill[]) playerBills;
    PlayerBill[] buyFrontBillQueue;
    PlayerBill[] buyBackBillQueue;

    constructor(address _root, address _broker) {
        parent = msg.sender;
        root = _root;
        broker = _broker;
        uint256 oddunit = 0.0001 * (10 ** 18);
        uint256 initialPrice = 1;
        uint16 kickbackRate = 20;
        uint16 brokerageRate = 70;
        uint16 taxRate = 100 - brokerageRate;
        bulletinBoard = BulletinBoard(
            oddunit,
            initialPrice,
            0,
            kickbackRate,
            brokerageRate,
            taxRate
        );
    }

    modifier onlyRoot() {
        require(msg.sender == root, "Only root can call this.");
        _;
    }

    modifier onlyBroker() {
        require(msg.sender == broker, "Only broker can call this.");
        _;
    }
    modifier mustRunning() {
        require(running, "oddsdex has stopped");
        _;
    }
    modifier checkLuckyNumberByBrokerHash(uint256 luckyNumber) {
        bytes32 packed = keccak256(abi.encodePacked(luckyNumber));
        uint256 _hash = uint256(packed);
        require(_hash == coverHash, "LuckyNumber verification failed");
        _;
    }

    function getState() public view override returns (OddsdexState) {
        return state;
    }

    function getWeiPrice() public view override returns (uint256) {
        return bulletinBoard.oddunit * bulletinBoard.price;
    }

    function getBulletinBoard()
        public
        view
        override
        returns (BulletinBoard memory)
    {
        return bulletinBoard;
    }

    function isRunning() public view override returns (bool) {
        return running;
    }

    function stop() public override {
        running = false;
    }

    function run() public override {
        running = true;
    }

    function getRoot() public view override returns (address) {
        return root;
    }

    function getBroker() public view override returns (address) {
        return broker;
    }

    function oddBalanceOf(address _player) public override returns (uint256) {}

    function cover(uint256 _hash) public override onlyBroker mustRunning {
        require(
            state == OddsdexState.matchmaked,
            "Must have matchmaked before calling"
        );
        coverHash = _hash;
        state = OddsdexState.covering;
    }

    function lottery(
        uint256 _luckyNumber
    )
        public
        override
        onlyBroker
        mustRunning
        checkLuckyNumberByBrokerHash(_luckyNumber)
        returns (CoinDirection)
    {
        require(
            state == OddsdexState.covering,
            "Must have covering before calling"
        );
        state == OddsdexState.lottering;
        winningDirection = _calculateWinning(_luckyNumber);
        state == OddsdexState.lottered;
        return winningDirection;
    }

    function _calculateWinning(
        uint256 _luckyNumber
    ) internal view returns (CoinDirection) {
        uint total = _luckyNumber;
        for (uint i = 0; i < buyFrontBillQueue.length; i++) {
            uint32 luckyNumberOfPlayer = buyFrontBillQueue[i].luckyNumber;
            total += luckyNumberOfPlayer;
        }
        for (uint i = 0; i < buyBackBillQueue.length; i++) {
            uint32 luckyNumberOfPlayer = buyBackBillQueue[i].luckyNumber;
            total += luckyNumberOfPlayer;
        }
        uint v = total % 2;
        if (v == 1) {
            return CoinDirection.front;
        } else {
            return CoinDirection.back;
        }
    }

    function canMatchmaking() public view override onlyBroker returns (bool) {
        if (state != OddsdexState.lottered) {
            return false;
        }
        PlayerBill memory tailF;
        if (buyFrontBillQueue.length > 0) {
            tailF = buyFrontBillQueue[buyFrontBillQueue.length - 1];
        }
        PlayerBill memory tailB;
        if (buyBackBillQueue.length > 0) {
            tailB = buyBackBillQueue[buyBackBillQueue.length - 1];
        }

        if (winningDirection == CoinDirection.front) {
            return tailF.buyPrice <= tailB.buyPrice;
        } else if (winningDirection == CoinDirection.back) {
            return tailB.buyPrice <= tailF.buyPrice;
        } else {
            return false;
        }
    }

    function matchmake() public override onlyBroker {
        require(
            state == OddsdexState.lottered,
            "Must have lottered before calling"
        );
        state == OddsdexState.matchmaking;
        if (canMatchmaking()) {
            _matchmakePairBill();
        }
        state == OddsdexState.matchmaked;
    }

    function _matchmakePairBill() internal {
        //撮合一次对单之后，吃不掉的还在队列中，因此等下轮撮合，所以只考虑撮合当前对单即可
        PlayerBill memory tailF;
        if (buyFrontBillQueue.length > 0) {
            tailF = buyFrontBillQueue[buyFrontBillQueue.length - 1];
            buyFrontBillQueue.pop();
        }

        PlayerBill memory tailB;
        if (buyBackBillQueue.length > 0) {
            tailB = buyBackBillQueue[buyBackBillQueue.length - 1];
            buyBackBillQueue.pop();
        }

        uint256 dealOdds = _min(tailF.odds, tailB.odds);
        uint256 dealPrice = (tailF.buyPrice.add(tailB.buyPrice)).div(2);
        uint256 tailFOdds = tailF.odds.sub(dealOdds);
        uint256 tailBOdds = tailB.odds.sub(dealOdds);
        uint256 tailFCostOnBill = tailFOdds.mul(tailF.buyPrice);
        uint256 tailBCostOnBill = tailBOdds.mul(tailB.buyPrice);

        if (tailFOdds > 0) {
            tailF.costs = tailFCostOnBill;
            tailF.odds = tailFOdds;
            buyFrontBillQueue.push(tailF);
        }
        if (tailBOdds > 0) {
            tailB.costs = tailBCostOnBill;
            tailB.odds = tailBOdds;
            buyBackBillQueue.push(tailB);
        }

        uint256 prize = dealOdds.mul(dealPrice);
        uint256 tailFReturnCost = tailF.odds.mul(tailF.buyPrice).sub(
            tailFCostOnBill
        );
        uint256 tailBReturnCost = tailB.odds.mul(tailB.buyPrice).sub(
            tailBCostOnBill
        );

        _returnCost(tailFReturnCost, tailF.owner);
        _returnCost(tailBReturnCost, tailB.owner);

        if (winningDirection == CoinDirection.front) {
            _splitPrize(prize, tailF.owner);
        } else if (winningDirection == CoinDirection.back) {
            _splitPrize(prize, tailB.owner);
        } else {}

        bulletinBoard.price = dealPrice;
        bulletinBoard.odds -= dealOdds;
    }

    function _returnCost(uint256 cost, address player) internal {
        (bool success, ) = payable(player).call{value: cost}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
    }

    function _splitPrize(uint256 prize, address player) internal {
        uint256 kickback=prize.mul(bulletinBoard.kickbackRate).div(100);
        uint256 bonusOfPlayer=prize.sub(kickback);
        uint256 brokerage=kickback.mul(bulletinBoard.brokerageRate).div(100);
        uint256 tax=kickback.sub(brokerage);

        (bool success, ) = payable(player).call{value: bonusOfPlayer}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");
        (bool success1, ) = payable(broker).call{value: brokerage}(
            new bytes(0)
        );
        require(success1, "ETH_TRANSFER_FAILED");
        (bool success2, ) = payable(root).call{value: tax}(new bytes(0));
        require(success2, "ETH_TRANSFER_FAILED");

    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    fallback() external payable {
        require(false, "No other calls supported");
    }

    receive() external payable {
        require(false, "No other calls supported");
    }

    function stake(
        CoinDirection buyDirection,
        uint32 luckyNumber
    ) external payable override {
        require(
            buyDirection != CoinDirection.unknown,
            "Buying direction is unknown"
        );
        require(
            state != OddsdexState.matchmaking,
            "Do not accept orders when matching"
        );

        uint256 odds = msg.value.div(getWeiPrice());
        require(odds >= 10, "Minimum purchase of 10 odds");

        bulletinBoard.odds += odds;

        bytes memory idBytes = abi.encodePacked(
            block.timestamp,
            block.prevrandao
        );
        string memory id = string(idBytes);
        PlayerBill memory bill = PlayerBill(
            id,
            msg.sender,
            odds,
            msg.value,
            bulletinBoard.price,
            buyDirection,
            gasleft(),
            luckyNumber
        );

        playerBills[msg.sender].push(bill);

        if (buyDirection == CoinDirection.front) {
            buyFrontBillQueue.push(bill);
            _insertionSort(buyFrontBillQueue);
        } else if (buyDirection == CoinDirection.back) {
            buyBackBillQueue.push(bill);
            _insertionSort(buyBackBillQueue);
        } else {}

        emit OnBuyOrder(bill);
    }

    function _insertionSort(PlayerBill[] memory a) internal pure {
        for (uint i = 1; i < a.length; i++) {
            PlayerBill memory temp = a[i];
            uint j;
            for (j = i - 1; j >= 0 && temp.buyPrice < a[j].buyPrice; j--)
                a[j + 1] = a[j];
            a[j + 1] = temp;
        }
    }
}
