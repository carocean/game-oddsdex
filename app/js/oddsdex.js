$(document).ready(async function () {
    const web3 = new Web3(window.ethereum);

    const refreshDetails = async function () {
        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }
        $.get('/api/oddsdex.details', { address: contractAddress }, function (data) {
            console.log(data);
            var obj = JSON.parse(data);
            var state = '';
            switch (parseInt(obj.state)) {
                case 0:
                    state = '已扪';
                    break;
                case 1:
                    state = '正在开奖';
                    break;
                case 2:
                    state = '已开奖';
                    break;
                case 3:
                    state = '正在撮合';
                    break;
                case 4:
                    state = '已撮合';
                    break;
            }
            var panel = $('.dx-panel');
            panel.find('.dx-dts[state] span').html(state);
            panel.find('.dx-dts[isRunning] span').html(obj.isRunning == true ? '正在运行' : '停止');
            panel.find('.dx-dts[price] span').html(obj.bulletinBoard.price + '');
            panel.find('.dx-dts[kickbackRate]>span').html(obj.bulletinBoard.kickbackRate / 100);
            panel.find('.dx-dts[kickbackRate] li[brokerageRate] span').html(obj.bulletinBoard.brokerageRate / 100);
            panel.find('.dx-dts[kickbackRate] li[taxRate] span').html(obj.bulletinBoard.taxRate / 100);
        })
    }
    refreshDetails();
});