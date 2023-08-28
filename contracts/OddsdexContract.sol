// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.20;
import "./IOddsdex.sol";
import "./SafeMath.sol";
import "./Strings.sol";

contract OddsdexContract is IOddsdexContract {
    using SafeMath for *;

    bool private running;
    address private root;
    address private broker;
    address private parent;
    BulletinBoard private bulletinBoard;
    StakeBill[8 * 32] private stakeBills;
    uint8[32] private stakeBillsBitmap;

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
            0,
            kickbackRate,
            brokerageRate,
            taxRate
        );
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

    function getBalance() public view override returns (uint256) {
        return address(this).balance;
    }

    function getQueueCount() public view override returns (uint256) {
        return _lengthOfStakeBills(true, CoinDirection.unknown);
    }

    function getFrontQueueCount() public view override returns (uint256) {
        return _lengthOfStakeBills(false, CoinDirection.front);
    }

    function getBackQueueCount() public view override returns (uint256) {
        return _lengthOfStakeBills(false, CoinDirection.back);
    }

    function getTopFiveBillFrontQueue()
        public
        view
        override
        returns (uint32 length, StakeBill[5] memory bills)
    {
        (length, , bills) = _topFiveOfStakeBill(CoinDirection.front);
        return (length, bills);
    }

    function getTopFiveBillBackQueue()
        public
        view
        override
        returns (uint32 length, StakeBill[5] memory bills)
    {
        (length, , bills) = _topFiveOfStakeBill(CoinDirection.back);
        return (length, bills);
    }

    function getFirstBillOfFrontQueue()
        public
        view
        override
        returns (uint32 bitIndexAt, StakeBill memory bill)
    {
        return _topFirstOfStakeBill(CoinDirection.front);
    }

    function getFirstBillOfBackQueue()
        public
        view
        override
        returns (uint32 bitIndexAt, StakeBill memory bill)
    {
        return _topFirstOfStakeBill(CoinDirection.back);
    }

    function getStakeBill(
        uint32 index
    ) public view override returns (bool exists, StakeBill memory bill) {
        uint32 count;
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint8 v = uint8(b & (2 ** j));
                if (v == 2 ** j) {
                    if (count == index) {
                        return (true, stakeBills[i * 8 + j]);
                    }
                    count++;
                }
            }
        }
        StakeBill memory ret;
        return (false, ret);
    }

    function _calculateWinningDirection()
        internal
        view
        returns (LuckyNumber memory lvar, CoinDirection winningDirection)
    {
        lvar.r1 = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            ) % 10
        );
        lvar.r2 = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        lvar.r1
                    )
                )
            ) % 10
        );

        lvar.r3 = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        lvar.r1,
                        lvar.r2
                    )
                )
            ) % 10
        );
        lvar.r4 = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        lvar.r1,
                        lvar.r2,
                        lvar.r3
                    )
                )
            ) % 10
        );
        lvar.r5 = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        lvar.r1,
                        lvar.r2,
                        lvar.r3,
                        lvar.r4
                    )
                )
            ) % 10
        );

        uint256 totalF = _totalLuckyNumber(CoinDirection.front);
        uint256 totalB = _totalLuckyNumber(CoinDirection.back);

        lvar.f = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        totalF
                    )
                )
            ) % 10
        );
        lvar.b = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        totalB
                    )
                )
            ) % 10
        );

        uint256 v = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    msg.sender,
                    lvar.r1,
                    lvar.r2,
                    lvar.r3,
                    lvar.r4,
                    lvar.r5,
                    lvar.f,
                    lvar.b
                )
            )
        ) % 2;
        lvar.sign = v;
        if (v == 1) {
            return (lvar, CoinDirection.front);
        } else {
            return (lvar, CoinDirection.back);
        }
    }

    function _totalLuckyNumber(
        CoinDirection direction
    ) private view returns (uint256 total) {
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint8 v = uint8(b & (2 ** j));
                if (v == 2 ** j) {
                    StakeBill memory bill = stakeBills[i * 8 + j];
                    if (bill.buyDirection != direction) {
                        continue;
                    }
                    total += bill.luckyNumber;
                }
            }
        }
        return total;
    }

    function canMatchmaking(
        CoinDirection winningDirection
    ) public view override returns (bool matched) {
        (uint32 bitIndexAtF, StakeBill memory tailF) = _topFirstOfStakeBill(
            CoinDirection.front
        );
        if (bitIndexAtF == 0xFFFFFFFF) {
            return false;
        }
        (uint32 bitIndexAtB, StakeBill memory tailB) = _topFirstOfStakeBill(
            CoinDirection.back
        );
        if (bitIndexAtB == 0xFFFFFFFF) {
            return false;
        }

        if (winningDirection == CoinDirection.front) {
            return tailF.buyPrice <= tailB.buyPrice;
        } else if (winningDirection == CoinDirection.back) {
            return tailB.buyPrice <= tailF.buyPrice;
        } else {
            return false;
        }
    }

    function matchmake() public override onlyBroker mustRunning {
        uint32 matchmakeTimes;
        (, CoinDirection _winningDirection) = _calculateWinningDirection();
        while (canMatchmaking(_winningDirection)) {
            _matchmakePairBill(_winningDirection);
            matchmakeTimes++;
        }
        emit OnMatchmakeReturn(matchmakeTimes, _winningDirection);
    }

    struct LocalVar {
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
        bytes32 matchmakingBillId;
    }

    function _matchmakePairBill(CoinDirection winningDirection) private {
        //撮合一次对单之后，吃不掉的再次放入队列中，因此等下轮撮合，所以只考虑撮合当前对单即可
        (uint32 bitIndexAtF, StakeBill memory tailF) = _topFirstOfStakeBill(
            CoinDirection.front
        );
        if (bitIndexAtF == 0xFFFFFFFF) {
            return;
        }
        (uint32 bitIndexAtB, StakeBill memory tailB) = _topFirstOfStakeBill(
            CoinDirection.back
        );
        if (bitIndexAtB == 0xFFFFFFFF) {
            return;
        }
        //将两单移除，如果有剩余再放到队列
        _removeStakeBill(bitIndexAtF);
        _removeStakeBill(bitIndexAtB);

        LocalVar memory lvar;
        //撮合成交
        lvar.dealOdds = _min(tailF.odds, tailB.odds);
        lvar.dealPrice = (tailF.buyPrice.add(tailB.buyPrice)).div(2);
        lvar.tailFOdds = tailF.odds.sub(lvar.dealOdds);
        lvar.tailBOdds = tailB.odds.sub(lvar.dealOdds);
        lvar.tailFCostOnBill = lvar.tailFOdds.mul(tailF.buyPrice).mul(
            bulletinBoard.oddunit
        );
        lvar.tailBCostOnBill = lvar.tailBOdds.mul(tailB.buyPrice).mul(
            bulletinBoard.oddunit
        );

        //如果有剩余则存回
        if (lvar.tailFOdds > 0) {
            tailF.costs = lvar.tailFCostOnBill;
            tailF.odds = lvar.tailFOdds;
            storeStakeBill(tailF);
        }
        if (lvar.tailBOdds > 0) {
            tailB.costs = lvar.tailBCostOnBill;
            tailB.odds = lvar.tailBOdds;
            storeStakeBill(tailB);
        }

        lvar.prize = lvar.dealOdds.mul(lvar.dealPrice).mul(
            bulletinBoard.oddunit
        );
        lvar.tailFRefundCost = tailF
            .odds
            .mul(tailF.buyPrice)
            .mul(bulletinBoard.oddunit)
            .sub(lvar.tailFCostOnBill);
        lvar.tailBRefundCost = tailB
            .odds
            .mul(tailB.buyPrice)
            .mul(bulletinBoard.oddunit)
            .sub(lvar.tailBCostOnBill);

        //Verify Balance
        uint256 minimumBalance = lvar
            .prize
            .add(lvar.tailFRefundCost)
            .add(lvar.tailBRefundCost);
            // .add(0.1*(10**18));//Estimating gas fee, Set to 1 because dynamic estimation is also inaccurate
        require(
            address(this).balance >= minimumBalance,
            string.concat(
                "Insufficient contract balance. minimum balance: ",
                Strings.toString(minimumBalance)
            )
        );

        //mtn is Matchmaking transaction number
        lvar.mtn = bytes32(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );

        _refundCost(lvar.mtn, lvar.tailFRefundCost, tailF);
        _refundCost(lvar.mtn, lvar.tailBRefundCost, tailB);

        if (winningDirection == CoinDirection.front) {
            _splitPrize(lvar.mtn, lvar.prize, tailF);
        } else if (winningDirection == CoinDirection.back) {
            _splitPrize(lvar.mtn, lvar.prize, tailB);
        } else {}

        bulletinBoard.price = lvar.dealPrice;
        bulletinBoard.odds -= lvar.dealOdds;

        lvar.matchmakingBillId = bytes32(
            keccak256(abi.encodePacked(block.timestamp, block.difficulty))
        );

        MatchmakingBill memory _mbill = MatchmakingBill(
            lvar.matchmakingBillId,
            tailF.id,
            tailB.id,
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
            lvar.prize,
            winningDirection
        );
        emit OnMatchMakingEvent(_mbill);
    }

    function _refundCost(
        bytes32 mtn,
        uint256 costs,
        StakeBill memory bill
    ) private {
        if (costs == 0) {
            return;
        }
        address player = bill.owner;
        (bool success, ) = payable(player).call{value: costs}(new bytes(0));
        require(
            success,
            string(
                abi.encodePacked(
                    "ETH_TRANSFER_FAILED: Refund to palyer. Refund costs: ",
                    Strings.toString(costs),
                    ", player: ",
                    player
                )
            )
        );

        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        );
        RefundBill memory _rbill = RefundBill(
            idBytes,
            bill.id,
            mtn,
            player,
            costs
        );
        emit OnRefundBillEvent(_rbill);
    }

    function _splitPrize(
        bytes32 mtn,
        uint256 prize,
        StakeBill memory bill
    ) private {
        address player = bill.owner;
        uint256 kickback = prize.mul(bulletinBoard.kickbackRate).div(100);
        uint256 bonusOfPlayer = prize.sub(kickback);
        uint256 brokerage = kickback.mul(bulletinBoard.brokerageRate).div(100);
        uint256 tax = kickback.sub(brokerage);

        (bool success, ) = payable(player).call{value: bonusOfPlayer}(
            new bytes(0)
        );
        require(
            success,
            string(
                abi.encodePacked(
                    "ETH_TRANSFER_FAILED: split prize to palyer. bonus: ",
                    Strings.toString(bonusOfPlayer),
                    ", player: ",
                    player
                )
            )
        );
        (bool success1, ) = payable(broker).call{value: brokerage}(
            new bytes(0)
        );
        require(
            success1,
            string(
                abi.encodePacked(
                    "ETH_TRANSFER_FAILED: split prize to broker. brokerage: ",
                    Strings.toString(bonusOfPlayer)
                )
            )
        );
        (bool success2, ) = payable(root).call{value: tax}(new bytes(0));
        require(
            success2,
            string(
                abi.encodePacked(
                    "ETH_TRANSFER_FAILED: split prize to root. tax: ",
                    Strings.toString(bonusOfPlayer)
                )
            )
        );

        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty, msg.sender)
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

    function recharge() external payable onlyBroker mustRunning {
        require(msg.value > 0, "Feeding cannot be zero");
        RechargeBill memory bm = RechargeBill(
            msg.sender,
            msg.value,
            address(this).balance,
            gasleft()
        );
        emit OnRechargeEvent(bm);
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
    ) external payable override mustRunning {
        require(
            buyDirection != CoinDirection.unknown,
            "Buying direction is unknown"
        );

        uint256 odds = msg.value.div(bulletinBoard.oddunit.mul(buyPrice));
        // require(odds >= 10, "Minimum purchase of 10 odds");
        bulletinBoard.odds = bulletinBoard.odds.add(odds);
        bulletinBoard.funds = bulletinBoard.funds.add(msg.value);
        bytes32 idBytes = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        );
        StakeBill memory bill = StakeBill(
            idBytes,
            msg.sender,
            odds,
            msg.value,
            buyPrice,
            bulletinBoard.price,
            buyDirection,
            gasleft(),
            luckyNumber
        );
        storeStakeBill(bill);
        emit OnStakeBillEvent(bill);
    }

    function _getFirstSpaceBit() private view returns (uint32) {
        uint32 index = 0xFFFFFFFF;
        bool found;
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint v = b & (2 ** j);
                if (v == 0) {
                    index = i * 8 + j;
                    found = true;
                    break;
                }
            }
            if (found) {
                break;
            }
        }
        return index;
    }

    function _lengthOfStakeBills(
        bool all,
        CoinDirection direction
    ) private view returns (uint32) {
        uint32 len = 0;
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint8 v = uint8(b & (2 ** j));
                if (v == 2 ** j) {
                    StakeBill memory bill = stakeBills[i * 8 + j];
                    if (!all && bill.buyDirection != direction) {
                        continue;
                    }
                    len++;
                }
            }
        }
        return len;
    }

    function _topFiveOfStakeBill(
        CoinDirection direction
    )
        private
        view
        returns (
            uint32 length,
            uint32[5] memory bitIndexAts,
            StakeBill[5] memory bills
        )
    {
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint8 v = uint8(b & (2 ** j));
                if (v == 2 ** j) {
                    StakeBill memory bill = stakeBills[i * 8 + j];
                    if (bill.buyDirection != direction) {
                        continue;
                    }
                    if (bill.buyPrice < bills[0].buyPrice) {
                        continue;
                    }
                    uint pos = bills.length;
                    for (int t = int(bills.length - 1); t > -1; t--) {
                        if (bill.buyPrice > bills[uint(t)].buyPrice) {
                            pos = uint(t);
                            _moveFronts(bitIndexAts, bills, pos);
                            bills[pos] = bill;
                            bitIndexAts[pos] = i * 8 + j;
                            length++;
                            break;
                        }
                    }
                }
            }
        }
        if (length > bills.length) {
            length = uint32(bills.length);
        }
        return (length, bitIndexAts, bills);
    }

    function _moveFronts(
        uint32[5] memory bitIndexAts,
        StakeBill[5] memory bills,
        uint pos
    ) private pure {
        for (uint i = 1; i <= pos; i++) {
            bills[i - 1] = bills[i];
            bitIndexAts[i - 1] = bitIndexAts[i];
        }
    }

    function _topFirstOfStakeBill(
        CoinDirection direction
    ) private view returns (uint32 bitIndexAt, StakeBill memory bill) {
        StakeBill memory maxbill;
        bitIndexAt = 0xFFFFFFFF;
        for (uint32 i = 0; i < stakeBillsBitmap.length; i++) {
            uint8 b = stakeBillsBitmap[i];
            for (uint8 j = 0; j < 8; j++) {
                uint8 v = uint8(b & (2 ** j));
                if (v == 2 ** j) {
                    bill = stakeBills[i * 8 + j];
                    if (bill.buyDirection != direction) {
                        continue;
                    }
                    if (bill.buyPrice > maxbill.buyPrice) {
                        maxbill = bill;
                        bitIndexAt = i * 8 + j;
                    }
                }
            }
        }
        return (bitIndexAt, maxbill);
    }

    function _removeStakeBill(uint32 index) private {
        uint32 i = index / 8;
        uint32 j = index % 8;
        uint8 v = stakeBillsBitmap[i];
        v = uint8(v & (~(2 ** j)));
        stakeBillsBitmap[i] = v;
    }

    function _setStakeBillAt(uint32 index) private {
        uint32 i = index / 8;
        uint32 j = index % 8;
        uint8 v = stakeBillsBitmap[i];
        v = uint8(v | (2 ** j));
        stakeBillsBitmap[i] = v;
    }

    function storeStakeBill(StakeBill memory bill) private {
        uint32 index = _getFirstSpaceBit();
        require(index != 0xFFFFFFFF, "Stake Bill Array space is full");
        stakeBills[index] = bill;
        _setStakeBillAt(index);
    }
}
