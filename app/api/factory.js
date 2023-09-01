const url = require('url');
var Web3 = require("web3");
var path = require('path');
const contract = require("@truffle/contract");
const { time } = require('console');

const provider = new Web3.providers.WebsocketProvider('ws://192.168.1.254:8545');
const web3 = new Web3(provider);


var factoryAbifile = path.resolve('./') + '/build/contracts/GamblingContractFactory.json';
const contractArtifact = require(factoryAbifile); //produced by Truffle compile
const GamblingContractFactory = contract(contractArtifact);
GamblingContractFactory.setProvider(provider);

const _getFactoryContract = async function () {
    const instance = await GamblingContractFactory.deployed();
    return instance;
}

module.exports.getFeeInfo = async function (req, res) {
    var instance = await _getFactoryContract();

    var uri = url.parse(req.url, true);
    var payMode = uri.query['payMode'];
    var intPayMode = parseInt(payMode);
    var address = instance.address;
    var annualFee = await instance.getAnnualFee();
    var monthlyFee = await instance.getMonthlyFee();
    switch (intPayMode) {
        case 1:
            res.end(JSON.stringify({
                address: address,
                fee: web3.utils.fromWei(annualFee, 'ether')
            }));
            break;
        case 2:
            res.end(JSON.stringify({
                address: address,
                fee: web3.utils.fromWei(monthlyFee, 'ether')
            }));
            break;
    }
}

module.exports.getBalance = async function (req, res) {
    var instance = await _getFactoryContract();
    var balance = await instance.getBalance();
    res.end(web3.utils.fromWei(balance, 'ether') + "");
}

module.exports.isValidBroker = async function (req, res) {
    var instance = await _getFactoryContract();
    var uri = url.parse(req.url, true);
    var broker = uri.query['broker'];
    var isValidBroker = await instance.isValidBroker(broker);
    res.end(isValidBroker + "");
}

module.exports.create = async function (req, res) {
    var uri = url.parse(req.url, true);
    var broker = uri.query['broker'];

    var address = await _create(broker);
    console.log('newContract:' + address);
    var map = { contractAddress: address }

    res.end(JSON.stringify(map));
}
const _create = async function (broker, luckyCount) {
    var instance = await _getFactoryContract();
    await instance.OnCreateOddsdexContract(function (error, msg) {
        var raw = msg.raw;
        var data = raw.data;
        var topics = raw.topics;
        var zz = web3.eth.abi.decodeLog([{
            type: 'address',
            name: 'contractAddress'
        }, {
            type: 'address',
            name: 'root'
        }, {
            type: 'address',
            name: 'broker'
        }, {
            type: 'ApplyRights',
            name: 'rights',
            components: [
                {
                    type: 'bool',
                    name: 'isAllow',
                }, {
                    type: 'uint8',
                    name: 'payMode',
                }, {
                    type: 'uint',
                    name: 'time',
                }
            ]
        }],
            data,
            topics
        );
        console.log(zz);
    })
    var root=await instance.root();
    var result = await instance.createOddsdexContract(broker, { from: root });
    console.log(result.receipt.status);//是否成功
    //单返回值解码
    var zz = web3.eth.abi.decodeParameter(
        "address",
        result.receipt.rawLogs[0].data
    );

    //单或多返回值解码，解码后为数组
    // var zz = web3.eth.abi.decodeParameters(
    //     ["address"],
    //     result.receipt.rawLogs[0].data
    // );
    return zz;
}

module.exports.brokers = async function (req, res) {
    var instance = await _getFactoryContract();
    var result = await instance.enumBroker();
    console.log(result);
    res.end(JSON.stringify(result));
}

module.exports.contracts = async function (req, res) {
    var uri = url.parse(req.url, true);
    var broker = uri.query['broker'];
    var instance = await _getFactoryContract();
    // var param=web3.eth.abi.encodeParameter('address',broker);
    var result = await instance.listContractOfBroker(broker);
    console.log(result);
    res.end(JSON.stringify(result));
}

module.exports.withdraw = async function (req, res) {
    var instance = await _getFactoryContract();
    var root = await instance.root();
    await instance.withdraw({ from: root });
}