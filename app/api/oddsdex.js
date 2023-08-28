const sockets = require('../socketio.js');
const url = require('url');
var Web3 = require("web3");
var path = require('path');
const contract = require("@truffle/contract");
const { time } = require('console');

const provider = new Web3.providers.WebsocketProvider('ws://192.168.0.254:8545');
const web3 = new Web3(provider);


var oddsdexAbifile = path.resolve('./') + '/build/contracts/OddsdexContract.json';
const contractArtifact = require(oddsdexAbifile); //produced by Truffle compile
const OddsdexContract = contract(contractArtifact);
OddsdexContract.setProvider(provider);

const OnSplitBillEvent = async function (error, msg) {
    var raw = msg.raw;
    var data = raw.data;
    var topics = raw.topics;
    var zz = web3.eth.abi.decodeLog(
        [
            {
                type: 'bytes32',
                name: 'id'
            },
            , {
                type: 'bytes32',
                name: 'refId'
            }, {
                type: 'bytes32',
                name: 'mtn'
            }, {
                type: 'address',
                name: 'owner'
            }, {
                type: 'uint16',
                name: 'kickbackRate'
            }, {
                type: 'uint16',
                name: 'brokerageRate'
            }, {
                type: 'uint16',
                name: 'taxRate'
            }, {
                type: 'uint256',
                name: 'prize'
            }, {
                type: 'uint256',
                name: 'bonus'
            }, {
                type: 'uint256',
                name: 'kickback'
            }, {
                type: 'uint256',
                name: 'brokerage'
            }, {
                type: 'uint256',
                name: 'tax'
            }
        ],
        data,
        topics
    );
    var map = {
        id: zz['id'],
        refId: zz['refId'],
        mtn: zz['mtn'],
        owner: zz['owner'],
        kickbackRate: zz['kickbackRate'],
        brokerageRate: zz['brokerageRate'],
        taxRate: zz['taxRate'],
        prize: zz['prize'],
        bonus: zz['bonus'],
        kickback: zz['kickback'],
        brokerage: zz['brokerage'],
        tax: zz['tax'],
    }
    // res.end(JSON.stringify(map));
    var json = JSON.stringify(map);
    for (var key in sockets) {
        var socket = sockets[key];
        socket.emit('OnSplitBillEvent', json);
    }
}
const OnRefundBillEvent = async function (error, msg) {
    var raw = msg.raw;
    var data = raw.data;
    var topics = raw.topics;
    var zz = web3.eth.abi.decodeLog(
        [
            {
                type: 'bytes32',
                name: 'id'
            },
            , {
                type: 'bytes32',
                name: 'refId'
            }, {
                type: 'bytes32',
                name: 'mtn'
            }, {
                type: 'address',
                name: 'owner'
            }, {
                type: 'uint256',
                name: 'costs'
            }
        ],
        data,
        topics
    );
    var map = {
        id: zz['id'],
        refId: zz['refId'],
        mtn: zz['mtn'],
        owner: zz['owner'],
        costs: zz['costs'],
    }
    // res.end(JSON.stringify(map));
    var json = JSON.stringify(map);
    for (var key in sockets) {
        var socket = sockets[key];
        socket.emit('OnRefundBillEvent', json);
    }
}
const OnMatchMakingEvent = async function (error, msg) {
    var raw = msg.raw;
    var data = raw.data;
    var topics = raw.topics;
    var zz = web3.eth.abi.decodeLog(
        [
            {
                type: 'bytes32',
                name: 'id'
            },
            , {
                type: 'bytes32',
                name: 'refFId'
            }, {
                type: 'bytes32',
                name: 'refBId'
            }, {
                type: 'bytes32',
                name: 'mtn'
            }, {
                type: 'address',
                name: 'broker'
            }, {
                type: 'uint256',
                name: 'dealOdds'
            }, {
                type: 'uint256',
                name: 'dealPrice'
            }, {
                type: 'uint256',
                name: 'tailFOdds'
            }, {
                type: 'uint256',
                name: 'tailBOdds'
            }, {
                type: 'uint256',
                name: 'tailFCostOnBill'
            }, {
                type: 'uint256',
                name: 'tailBCostOnBill'
            }, {
                type: 'uint256',
                name: 'tailFRefundCosts'
            }, {
                type: 'uint256',
                name: 'tailBRefundCosts'
            }, {
                type: 'uint256',
                name: 'prize'
            }, {
                type: 'uint8',
                name: 'winningDirection'
            }
        ],
        data,
        topics
    );
    var map = {
        id: zz['id'],
        refFId: zz['refFId'],
        refBId: zz['refBId'],
        mtn: zz['mtn'],
        broker: zz['broker'],
        dealOdds: zz['dealOdds'],
        dealPrice: zz['dealPrice'],
        tailFOdds: zz['tailFOdds'],
        tailBOdds: zz['tailBOdds'],
        tailFCostOnBill: zz['tailFCostOnBill'],
        tailBCostOnBill: zz['tailBCostOnBill'],
        tailFRefundCosts: zz['tailFRefundCosts'],
        tailBRefundCosts: zz['tailBRefundCosts'],
        prize: zz['prize'],
        winningDirection: zz['winningDirection']
    }
    // res.end(JSON.stringify(map));
    var json = JSON.stringify(map);
    for (var key in sockets) {
        var socket = sockets[key];
        socket.emit('OnMatchMakingEvent', json);
    }
}
const OnStakeBillEvent = async function (error, msg) {
    var raw = msg.raw;
    var data = raw.data;
    var topics = raw.topics;
    //单或多返回值解码，解码后为数组
    // var zz = web3.eth.abi.decodeParameters(
    //     [
    //         "bytes32",
    //         "address",
    //         "uint256",
    //         "uint256",
    //         "uint256",
    //         "uint8",
    //         "uint256",
    //         "uint32"
    //     ],
    //     data
    // );
    var zz = web3.eth.abi.decodeLog(
        [
            {
                type: 'bytes32',
                name: 'id'
            },
            , {
                type: 'address',
                name: 'owner'
            }, {
                type: 'uint256',
                name: 'odds'
            }, {
                type: 'uint256',
                name: 'costs'
            }, {
                type: 'uint256',
                name: 'buyPrice'
            }, {
                type: 'uint256',
                name: 'marketPrice'
            }, {
                type: 'uint8',
                name: 'buyDirection'
            }, {
                type: 'uint256',
                name: 'gas'
            }, {
                type: 'uint32',
                name: 'luckyNumber'
            }
        ],
        data,
        topics
    );
    // console.log(zz);
    var map = {
        id: web3.utils.hexToNumberString(zz['id']),
        owner: zz['owner'],
        odds: parseInt(zz['odds']),
        costs: parseInt(zz['costs']),
        buyPrice: parseInt(zz['buyPrice']),
        buyDirection: parseInt(zz['buyDirection']),
        gas: parseInt(zz['gas']),
        luckyNumber: parseInt(zz['luckyNumber'])
    }

    // res.end(JSON.stringify(map));
    var json = JSON.stringify(map);
    for (var key in sockets) {
        var socket = sockets[key];
        socket.emit('OnStakeBillEvent', json);
    }
    // const instance = await OddsdexContract.at(msg.address);
    // stateController(web3, instance);
    console.log(map);
};

module.exports.listerners = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    instance.OnStakeBillEvent(OnStakeBillEvent);
    instance.OnMatchMakingEvent(OnMatchMakingEvent);
    instance.OnRefundBillEvent(OnRefundBillEvent);
    instance.OnSplitBillEvent(OnSplitBillEvent);
}
module.exports.matchmake = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    var broker = await instance.getBroker();
    await instance.matchmake({ from: broker });
}
module.exports.details = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    var root = await instance.getRoot();
    var broker = await instance.getBroker();
    var isRunning = await instance.isRunning();
    var bulletinBoard = await instance.getBulletinBoard();
    var queueCount = await instance.getQueueCount();
    var frontQueueCount = await instance.getFrontQueueCount();
    var backQueueCount = await instance.getBackQueueCount();
    var exchangeRate = web3.utils.fromWei((parseInt(bulletinBoard.oddunit) * parseInt(bulletinBoard.price)) + '', 'ether');
    var map = {
        root: root,
        broker:broker,
        isRunning: isRunning,
        exchangeRate: exchangeRate,
        bulletinBoard: {
            oddunit: parseInt(bulletinBoard.oddunit),
            price: parseInt(bulletinBoard.price),
            odds: parseInt(bulletinBoard.odds),
            funds: parseInt(bulletinBoard.funds),
            kickbackRate: parseInt(bulletinBoard.kickbackRate),
            brokerageRate: parseInt(bulletinBoard.brokerageRate),
            taxRate: parseInt(bulletinBoard.taxRate),
        },
        queueCount: parseInt(queueCount),
        frontQueueCount: parseInt(frontQueueCount),
        backQueueCount: parseInt(backQueueCount)
    };
    res.end(JSON.stringify(map));
}

module.exports.frontQueue = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    var queue = await instance.getTopFiveBillFrontQueue();
    var length = queue['length'];
    var bills = queue['bills'];
    var list = [];
    for (var i = bills.length - length; i < bills.length; i++) {
        var bill = bills[i];
        list.push({
            buyPrice: parseInt(bill['buyPrice']),
            odds: parseInt(bill['odds']),
            costs: parseInt(bill['costs']),
            player: bill['owner']
        });
    }
    res.end(JSON.stringify(list));
}
module.exports.backQueue = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    var queue = await instance.getTopFiveBillBackQueue();
    var length = queue['length'];
    var bills = queue['bills'];
    var list = [];
    for (var i = bills.length - 1; i >= bills.length - length; i--) {
        var bill = bills[i];
        list.push({
            buyPrice: parseInt(bill['buyPrice']),
            odds: parseInt(bill['odds']),
            costs: parseInt(bill['costs']),
            player: bill['owner']
        });
    }
    res.end(JSON.stringify(list));
}