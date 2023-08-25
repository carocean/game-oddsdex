// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;
import "./IOddsdex.sol";
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
    mapping(address => StakeBill[]) private stakeBills;
    StakeBill[] private buyFrontBillQueue;
    StakeBill[] private buyBackBillQueue;

    constructor(address _root, address _broker) {
        parent = msg.sender;
        root = _root;
        broker = _broker;
        uint256 initialPrice = 100;
        uint256 oddunit = 0.0001 * (10 ** 18);
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
        state = OddsdexState.matchmaked;
        running = true;
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

    function getFrontQueueCount() public view override returns (uint256) {
        return buyFrontBillQueue.length;
    }

    function getBackQueueCount() public view override returns (uint256) {
        return buyBackBillQueue.length;
    }

    function getFrontBillQueue(
        uint index
    ) public view override returns (StakeBill memory) {
        StakeBill memory bill;
        if (index >= buyFrontBillQueue.length) {
            return bill;
        }
        bill = buyFrontBillQueue[index];
        return bill;
    }

    function getBackBillQueue(
        uint index
    ) public view override returns (StakeBill memory) {
        StakeBill memory bill;
        if (index >= buyBackBillQueue.length) {
            return bill;
        }
        bill = buyBackBillQueue[index];
        return bill;
    }

    function getWinningDirection()
        public
        view
        override
        returns (CoinDirection)
    {
        return winningDirection;
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

    function costOnBillOfPlayer(
        address _player
    ) public view override returns (uint256) {
        StakeBill[] memory bills = stakeBills[_player];
        uint256 total;
        for (uint i = 0; i < bills.length; i++) {
            StakeBill memory bill = bills[i];
            total += bill.costs;
        }
        return total;
    }

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

        LotteryMessage memory message = LotteryMessage(
            winningDirection,
            _luckyNumber,
            broker,
            coverHash
        );

        emit OnLotteryEvent(message);

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
        StakeBill memory tailF;
        if (buyFrontBillQueue.length > 0) {
            tailF = buyFrontBillQueue[buyFrontBillQueue.length - 1];
        }
        StakeBill memory tailB;
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
        while (canMatchmaking()) {
            _matchmakePairBill();
        }
        state == OddsdexState.matchmaked;
    }

    struct LocalVar {
        StakeBill tailF;
        StakeBill tailB;
        uint256 dealOdds;
        uint256 dealPrice;
        uint256 tailFOdds;
        uint256 tailBOdds;
        uint256 tailFCostOnBill;
        uint256 tailBCostOnBill;
        bytes32 mtn;
        uint256 prize;
        uint256 tailFRefundCost;
        uint256 tailBRefundCost;
        bytes32 idNewBytes;
    }

    function _matchmakePairBill() internal {
        LocalVar memory lvar;
        //撮合一次对单之后，吃不掉的还在队列中，因此等下轮撮合，所以只考虑撮合当前对单即可
        if (buyFrontBillQueue.length > 0) {
            lvar.tailF = buyFrontBillQueue[buyFrontBillQueue.length - 1];
            buyFrontBillQueue.pop();
        }

        if (buyBackBillQueue.length > 0) {
            lvar.tailB = buyBackBillQueue[buyBackBillQueue.length - 1];
            buyBackBillQueue.pop();
        }

        lvar.dealOdds = _min(lvar.tailF.odds, lvar.tailB.odds);
        lvar.dealPrice = (lvar.tailF.buyPrice.add(lvar.tailB.buyPrice)).div(2);
        lvar.tailFOdds = lvar.tailF.odds.sub(lvar.dealOdds);
        lvar.tailBOdds = lvar.tailB.odds.sub(lvar.dealOdds);
        lvar.tailFCostOnBill = lvar.tailFOdds.mul(lvar.tailF.buyPrice);
        lvar.tailBCostOnBill = lvar.tailBOdds.mul(lvar.tailB.buyPrice);

        //mtn is Matchmaking transaction number
        lvar.mtn = bytes32(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );

        if (lvar.tailFOdds > 0) {
            lvar.tailF.costs = lvar.tailFCostOnBill;
            lvar.tailF.odds = lvar.tailFOdds;
            buyFrontBillQueue.push(lvar.tailF);
        }
        if (lvar.tailBOdds > 0) {
            lvar.tailB.costs = lvar.tailBCostOnBill;
            lvar.tailB.odds = lvar.tailBOdds;
            buyBackBillQueue.push(lvar.tailB);
        }

        lvar.prize = lvar.dealOdds.mul(lvar.dealPrice);
        lvar.tailFRefundCost = lvar.tailF.odds.mul(lvar.tailF.buyPrice).sub(
            lvar.tailFCostOnBill
        );
        lvar.tailBRefundCost = lvar.tailB.odds.mul(lvar.tailB.buyPrice).sub(
            lvar.tailBCostOnBill
        );

        _refundCost(lvar.mtn, lvar.tailFRefundCost, lvar.tailF);
        _refundCost(lvar.mtn, lvar.tailBRefundCost, lvar.tailB);

        if (winningDirection == CoinDirection.front) {
            _splitPrize(lvar.mtn, lvar.prize, lvar.tailF);
        } else if (winningDirection == CoinDirection.back) {
            _splitPrize(lvar.mtn, lvar.prize, lvar.tailB);
        } else {}

        bulletinBoard.price = lvar.dealPrice;
        bulletinBoard.odds -= lvar.dealOdds;

        lvar.idNewBytes = bytes32(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );

        MatchmakingBill memory _mbill = MatchmakingBill(
            lvar.idNewBytes,
            lvar.tailF.id,
            lvar.tailB.id,
            lvar.mtn,
            broker,
            lvar.dealOdds,
            lvar.dealPrice,
            lvar.tailFOdds,
            lvar.tailBOdds,
            lvar.tailFCostOnBill,
            lvar.tailBCostOnBill,
            lvar.tailFRefundCost,
            lvar.tailBRefundCost,
            lvar.prize
        );
        emit OnMatchMakingEvent(_mbill);
    }

    function _refundCost(
        bytes32 mtn,
        uint256 cost,
        StakeBill memory bill
    ) internal {
        address player = bill.owner;
        (bool success, ) = payable(player).call{value: cost}(new bytes(0));
        require(success, "ETH_TRANSFER_FAILED");

        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        );
        RefundBill memory _rbill = RefundBill(
            idBytes,
            bill.id,
            mtn,
            player,
            cost
        );
        emit OnRefundBillEvent(_rbill);
    }

    function _splitPrize(
        bytes32 mtn,
        uint256 prize,
        StakeBill memory bill
    ) internal {
        address player = bill.owner;
        uint256 kickback = prize.mul(bulletinBoard.kickbackRate).div(100);
        uint256 bonusOfPlayer = prize.sub(kickback);
        uint256 brokerage = kickback.mul(bulletinBoard.brokerageRate).div(100);
        uint256 tax = kickback.sub(brokerage);

        (bool success, ) = payable(player).call{value: bonusOfPlayer}(
            new bytes(0)
        );
        require(success, "ETH_TRANSFER_FAILED");
        (bool success1, ) = payable(broker).call{value: brokerage}(
            new bytes(0)
        );
        require(success1, "ETH_TRANSFER_FAILED");
        (bool success2, ) = payable(root).call{value: tax}(new bytes(0));
        require(success2, "ETH_TRANSFER_FAILED");

        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        );
        SplitBill memory _sbill = SplitBill(
            idBytes,
            bill.id,
            mtn,
            player,
            bulletinBoard.kickbackRate,
            bulletinBoard.brokerageRate,
            bulletinBoard.taxRate,
            prize,
            bonusOfPlayer,
            kickback,
            brokerage,
            tax
        );
        emit OnSplitBillEvent(_sbill);
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
        uint256 buyPrice,
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
        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        );
        StakeBill memory bill = StakeBill(
            idBytes,
            msg.sender,
            odds,
            msg.value,
            bulletinBoard.price,
            buyDirection,
            gasleft(),
            luckyNumber
        );
        stakeBills[msg.sender].push(bill);
        if (buyDirection == CoinDirection.front) {
            buyFrontBillQueue.push(bill);
            _insertionSort(buyFrontBillQueue);
        } else if (buyDirection == CoinDirection.back) {
            buyBackBillQueue.push(bill);
            _insertionSort(buyBackBillQueue);
        } else {}
        emit OnStakeBillEvent(bill);
    }

    function _insertionSort(StakeBill[] memory a) internal pure {
        for (uint i = 1; i < a.length; i++) {
            StakeBill memory temp = a[i];
            uint j;
            for (j = i - 1; j >= 0 && temp.buyPrice < a[j].buyPrice; j--)
                a[j + 1] = a[j];
            a[j + 1] = temp;
        }
    }
}
