//这两个变量应存储起来，不然重启之后又生成新的了，与合约不一致影响测试
//因为测试先写死
var currentLuckyNumber = '823833';
var currentCoverHash;

module.exports = async function (web3, instance) {
    var stateStr = await instance.getState();
    switch (parseInt(stateStr)) {
        case 0://covering,
            // var originHash = genHash(web3);
            // originHash=web3.utils.toBN(originHash);
            // var coverHash = await instance.getCoverHash();
            // var anyHash = await instance.genHash(new web3.utils.BN(currentLuckyNumber));
            // console.log('originHash=' + originHash + '\ncoverHash=' + coverHash + '\nanyHash=' + anyHash);
            var broker = await instance.getBroker();
            var result = await instance.lotteryDraw(new web3.utils.BN(currentLuckyNumber), { from: broker });
            var direction = web3.eth.abi.decodeParameter("uint8", result.receipt.rawLogs[0].data);
            console.log(direction);
            break;
        case 1://lottering,
            console.log('lottering');
            break;
        case 2://lottered,
            var broker = await instance.getBroker();
            await instance.matchmake({ from: broker });
            break;
        case 3:// matchmaking,
            console.log('matchmaking');
            break;
        case 4://matchmaked
            var coverHash = genHash(web3);
            currentCoverHash = coverHash;
            console.log(coverHash);
            var zz= await instance.getState();
            var broker = await instance.getBroker();
            await instance.cover(coverHash, { from: broker });
            break;
    }

}

const genHash = function (web3) {
    // var luckyNumber = genLuckyNumber();
    var luckyNumber = currentLuckyNumber;
    //web3.utils.soliditySha3等同于合约中的一对：keccak256(abi.encodePacked(number))
    var blindHash = web3.utils.soliditySha3(new web3.utils.BN(luckyNumber));
    return blindHash;
}

// const genLuckyNumber = function () {
//     var v1 = Math.floor(Math.random() * 9);
//     var v2 = Math.floor(Math.random() * 9);
//     var v3 = Math.floor(Math.random() * 9);
//     var v4 = Math.floor(Math.random() * 9);
//     var v5 = Math.floor(Math.random() * 9);
//     var v6 = Math.floor(Math.random() * 9);
//     var randomNum = v1 + '' + v2 + '' + v3 + '' + v4 + '' + v5 + '' + v6;
//     currentLuckyNumber = randomNum;
//     return currentLuckyNumber;
// }