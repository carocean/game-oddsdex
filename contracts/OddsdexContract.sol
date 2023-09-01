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
    uint104 private numberGenerator = 0;

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

    function canMatchmaking()
        public
        view
        override
        returns (bool matched, MatchmakingResult memory result)
    {
        //After matching an order, the uneatable ones will be placed in the queue again,
        //so wait for the next round of matching, so only consider matching the current order
        (uint32 bitIndexAtF, StakeBill memory tailF) = _topFirstOfStakeBill(
            CoinDirection.front
        );
        if (bitIndexAtF == 0xFFFFFFFF) {
            return (false, result);
        }
        (uint32 bitIndexAtB, StakeBill memory tailB) = _topFirstOfStakeBill(
            CoinDirection.back
        );
        if (bitIndexAtB == 0xFFFFFFFF) {
            return (false, result);
        }

        result.bitIndexAtF = bitIndexAtF;
        result.bitIndexAtB = bitIndexAtB;
        result.tailF = tailF;
        result.tailB = tailB;
        return (true, result);
    }

    function matchmake() public override onlyBroker mustRunning {
        uint32 matchmakeTimes = 0;
        (, CoinDirection _winningDirection) = _calculateWinningDirection();
        //Gas limitations and loops
        //A loop with a fixed number of iterations must be used, as the block gas is limited and the loop may result in contract termination
        //If the private chain upper limit can be adjusted during the development process, such as setting the gas limit parameter of Gananche large enough to handle the limited number of while requests.
        //For the sake of safety, it is best not to use a while loop. If it can be changed to an application layer loop call, it can be changed to save more processing fees.
        while (matchmakeTimes <= 5) {
            (bool matched, MatchmakingResult memory result) = canMatchmaking();
            if (!matched) {
                break;
            }
            _matchmakePairBill(_winningDirection, result);
            matchmakeTimes++;
        }

        emit OnMatchmakeReturn(matchmakeTimes, _winningDirection);
    }

    struct LocalVar {
        bytes16 mmid;
        uint256 dealOdds;
        uint256 dealPrice;
        uint256 tailFOdds;
        uint256 tailBOdds;
        uint256 tailFCostOnBill;
        uint256 tailBCostOnBill;
        uint256 prize;
        uint256 tailFRefundCost;
        uint256 tailBRefundCost;
        uint256 adjustRefundCost;
    }

    function _matchmakePairBill(
        CoinDirection winningDirection,
        MatchmakingResult memory result
    ) private {
        uint32 bitIndexAtF = result.bitIndexAtF;
        StakeBill memory tailF = result.tailF;
        uint32 bitIndexAtB = result.bitIndexAtB;
        StakeBill memory tailB = result.tailB;
        //Remove the two bills, and put them in the queue if there are any remaining
        _removeStakeBill(bitIndexAtF);
        _removeStakeBill(bitIndexAtB);

        LocalVar memory lvar;

        lvar.mmid = bytes16(abi.encodePacked("mm-", _numberGenerator()));

        lvar.adjustRefundCost = _adjustWinBill(
            winningDirection,
            lvar.mmid,
            tailF,
            tailB
        );

        //Make a deal

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

        //due prize
        lvar.prize = lvar.dealOdds.mul(lvar.dealPrice).mul(
            bulletinBoard.oddunit
        );

        //Calculate the funds to be returned
        if (winningDirection == CoinDirection.front) {
            lvar.tailFRefundCost = tailF
                .odds
                .mul(tailF.buyPrice)
                .mul(bulletinBoard.oddunit)
                .sub(lvar.tailFCostOnBill);
            lvar.tailBRefundCost = tailB
                .odds
                .mul(tailB.buyPrice)
                .mul(bulletinBoard.oddunit)
                .sub(lvar.tailBCostOnBill)
                .sub(lvar.prize);
        } else if (winningDirection == CoinDirection.back) {
            lvar.tailBRefundCost = tailB
                .odds
                .mul(tailB.buyPrice)
                .mul(bulletinBoard.oddunit)
                .sub(lvar.tailBCostOnBill);
            lvar.tailFRefundCost = tailF
                .odds
                .mul(tailF.buyPrice)
                .mul(bulletinBoard.oddunit)
                .sub(lvar.tailFCostOnBill)
                .sub(lvar.prize);
        }

        //restore if there is any remaining
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

        //Verify Balance
        uint256 minimumBalance = lvar.prize.add(lvar.tailFRefundCost).add(
            lvar.tailBRefundCost
        );

        require(
            address(this).balance >= minimumBalance,
            string.concat(
                "Insufficient contract balance. minimum balance: ",
                Strings.toString(minimumBalance)
            )
        );

        _refundCost(lvar.mmid, lvar.tailFRefundCost, tailF.owner);
        _refundCost(lvar.mmid, lvar.tailBRefundCost, tailB.owner);

        if (winningDirection == CoinDirection.front) {
            _splitPrize(lvar.mmid, lvar.prize, tailF.owner);
        } else if (winningDirection == CoinDirection.back) {
            _splitPrize(lvar.mmid, lvar.prize, tailB.owner);
        } else {}

        bulletinBoard.price = lvar.dealPrice;
        bulletinBoard.odds = bulletinBoard.odds.sub(lvar.dealOdds.mul(2));
        bulletinBoard.funds = bulletinBoard.funds.sub(
            lvar.tailFRefundCost.add(lvar.tailBRefundCost).add(
                lvar.adjustRefundCost
            )
        );

        MatchmakingBill memory _mbill = MatchmakingBill(
            lvar.mmid,
            tailF.id,
            tailB.id,
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

    function _adjustWinBill(
        CoinDirection winningDirection,
        bytes16 mmid,
        StakeBill memory tailF,
        StakeBill memory tailB
    ) private returns (uint256) {
        if (
            winningDirection == CoinDirection.front &&
            tailF.buyPrice > tailB.buyPrice
        ) {
            uint256 newodds = tailF.costs.div(
                tailB.buyPrice.mul(bulletinBoard.oddunit)
            );
            uint256 newcosts = newodds.mul(
                tailB.buyPrice.mul(bulletinBoard.oddunit)
            );
            uint256 refundCost = tailF.costs - newcosts;
            tailF.buyPrice = tailB.buyPrice;
            tailF.odds = newodds;
            tailF.costs = newcosts;
            _refundCost(mmid, refundCost, tailF.owner);
            return refundCost;
        } else if (
            winningDirection == CoinDirection.back &&
            tailB.buyPrice > tailF.buyPrice
        ) {
            uint256 newodds = tailB.costs.div(
                tailF.buyPrice.mul(bulletinBoard.oddunit)
            );
            uint256 newcosts = newodds.mul(
                tailF.buyPrice.mul(bulletinBoard.oddunit)
            );
            uint256 refundCost = tailB.costs - newcosts;
            tailB.buyPrice = tailF.buyPrice;
            tailB.odds = newodds;
            tailB.costs = newcosts;
            _refundCost(mmid, refundCost, tailB.owner);
            return refundCost;
        } else {
            return 0;
        }
    }

    function _refundCost(bytes16 mmid, uint256 costs, address owner) private {
        if (costs == 0) {
            return;
        }
        address player = owner;
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
        bytes16 id = bytes16(abi.encodePacked("rf-", _numberGenerator()));
        RefundBill memory _rbill = RefundBill(id, mmid, player, costs);
        emit OnRefundBillEvent(_rbill);
    }

    function _splitPrize(bytes16 mmid, uint256 prize, address owner) private {
        address player = owner;
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
        bytes16 id = bytes16(abi.encodePacked("st-", _numberGenerator()));
        SplitBill memory _sbill = SplitBill(
            id,
            mmid,
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
            bytes16(abi.encodePacked("rc-", _numberGenerator())),
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

        StakeBill memory bill = StakeBill(
            bytes16(abi.encodePacked("sk-", _numberGenerator())),
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

    function _numberGenerator() private returns (uint104) {
        return ++numberGenerator;
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
