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
    var canMatchmaking = await instance.canMatchmaking({from:broker});
    var map = {
        root: root,
        state: state,
        isRunning: isRunning,
        winningDirection: winningDirection,
        bulletinBoard: {
            oddunit: bulletinBoard.oddunit,
            price: bulletinBoard.price,
            odds: bulletinBoard.odds,
            kickbackRate: bulletinBoard.kickbackRate,
            brokerageRate: bulletinBoard.brokerageRate,
            taxRate: bulletinBoard.taxRate,
        },
        canMatchmaking: canMatchmaking
    };
    res.end(JSON.stringify(map));
}