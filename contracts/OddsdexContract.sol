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
    StakeBill[8 * 32] private stakeBills;
    uint8[32] stakeBillsBitmap;

    // StakeBill[10] private buyFrontBillQueue;
    // StakeBill[10] private buyBackBillQueue;

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

    function cover(uint256 _hash) public override onlyBroker mustRunning {
        require(
            state == OddsdexState.matchmaked,
            "Must have matchmaked before calling"
        );
        coverHash = _hash;
        state = OddsdexState.covering;
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
