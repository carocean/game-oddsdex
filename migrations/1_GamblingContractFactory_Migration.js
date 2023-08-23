const GamblingContractFactory = artifacts.require("./GamblingContractFactory.sol");
const OddsdexContract = artifacts.require("./OddsdexContract.sol");
module.exports = function (deployer, network, accounts) {
    for (var i = 0; i < accounts.length; i++) {
        var a = accounts[i];
        console.log(a);
    }
    deployer.deploy(OddsdexContract, accounts[0], accounts[0]);
    deployer.deploy(GamblingContractFactory);
}
