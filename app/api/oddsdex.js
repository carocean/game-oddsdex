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

const OnStakeBillEvent = function (error, msg) {
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
    console.log(map);
};

module.exports.listerners = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    instance.OnStakeBillEvent(OnStakeBillEvent);
}

module.exports.details = async function (req, res) {
    var uri = url.parse(req.url, true);
    var address = uri.query['address'];
    const instance = await OddsdexContract.at(address);

    var root = await instance.getRoot();
    var broker = await instance.getBroker();
    var state = await instance.getState();
    var isRunning = await instance.isRunning();
    var winningDirection = await instance.getWinningDirection();
    var bulletinBoard = await instance.getBulletinBoard();
    // var canMatchmaking = await instance.canMatchmaking({ from: broker });
    var winningDirection = await instance.getWinningDirection();
    var queueCount = await instance.getQueueCount();
    var frontQueueCount = await instance.getFrontQueueCount();
    var backQueueCount = await instance.getBackQueueCount();
    var exchangeRate = web3.utils.fromWei((parseInt(bulletinBoard.oddunit) * parseInt(bulletinBoard.price)) + '', 'ether');
    var map = {
        root: root,
        state: parseInt(state),
        isRunning: isRunning,
        winningDirection: parseInt(winningDirection),
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
        // canMatchmaking: canMatchmaking,
        winningDirection: parseInt(winningDirection),
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