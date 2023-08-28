$(document).ready(async function () {
    const web3 = new Web3(window.ethereum);

    sessionStorage.setItem("dx-bill", $('.dx-box .dx-queue .dx-bill').first().prop('outerHTML'));

    (function () {
        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }
        $('.dx-header li[contract] span').html(contractAddress);
        $.get('/api/oddsdex.listerners', { address: contractAddress }, function (data) {
            var socket = io();
            socket.on("connect", () => {
                console.log(socket.connected); // true
            });
            socket.on('OnStakeBillEvent', function (msg) {
                var obj = JSON.parse(msg);
                // var d = JSON.stringify(obj, null, "<br>");
                var e = $('<ul class="dx-jsonviewer"><li e-name><i>玩家买入[OnStakeBillEvent]:</i></li><li e-cnt><p></p></li></ul>');
                e.find('li[e-cnt] p').jsonViewer(obj);
                $('.dx-events').append(e);
                refreshDetails();
                refreshDealPanel();
            })
            socket.on('OnRechargeEvent', function (msg) {
                var obj = JSON.parse(msg);
                // var d = JSON.stringify(obj, null, "<br>");
                var e = $('<ul class="dx-jsonviewer"><li e-name><i>经纪人充值[OnRechargeEvent]:</i></li><li e-cnt><p></p></li></ul>');
                e.find('li[e-cnt] p').jsonViewer(obj);
                $('.dx-events').append(e);
                refreshDetails();
                refreshDealPanel();
            })
            socket.on('OnMatchMakingEvent', function (msg) {
                var obj = JSON.parse(msg);
                // var d = JSON.stringify(obj, null, "<br>");
                var e = $('<ul class="dx-jsonviewer"><li e-name><i>撮合[OnMatchMakingEvent]:</i></li><li e-cnt><p></p></li></ul>');
                e.find('li[e-cnt] p').jsonViewer(obj);
                $('.dx-events').append(e);
                refreshDetails();
                refreshDealPanel();
            })
            socket.on('OnRefundBillEvent', function (msg) {
                var obj = JSON.parse(msg);
                // var d = JSON.stringify(obj, null, "<br>");
                var e = $('<ul class="dx-jsonviewer"><li e-name><i>资金退回[OnRefundBillEvent]:</i></li><li e-cnt><p></p></li></ul>');
                e.find('li[e-cnt] p').jsonViewer(obj);
                $('.dx-events').append(e);
                refreshDetails();
                refreshDealPanel();
            })
            socket.on('OnSplitBillEvent', function (msg) {
                var obj = JSON.parse(msg);
                // var d = JSON.stringify(obj, null, "<br>");
                var e = $('<ul class="dx-jsonviewer"><li e-name><i>清算拆单[OnSplitBillEvent]:</i></li><li e-cnt><p></p></li></ul>');
                e.find('li[e-cnt] p').jsonViewer(obj);
                $('.dx-events').append(e);
                refreshDetails();
                refreshDealPanel();
            })
            // $('.dx-events').html('事件接收区已准备好<br>');
        });
    })();

    const refreshDealPanel = async function () {
        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }
        $.get('/api/oddsdex.frontQueue', { address: contractAddress }, function (data) {
            console.log(data);
            var list = JSON.parse(data);
            var fQueueE = $('.dx-front-q .dx-queue').first();
            var fBillE = $(sessionStorage.getItem("dx-bill"));
            fQueueE.empty();
            for (var i = 0; i < list.length; i++) {
                var bill = list[i];
                var e = fBillE.clone();
                e.find('.dx-field[buyPrice]').html((bill.buyPrice / 100.00).toFixed(2));
                e.find('.dx-field[odds]').html(bill.odds);
                e.find('.dx-field[costs]').html(parseFloat(web3.utils.fromWei(bill.costs, 'ether')).toFixed(6));
                e.find('.dx-field[player]').html(bill.player);
                fQueueE.append(e);
            }
        })
        $.get('/api/oddsdex.backQueue', { address: contractAddress }, function (data) {
            console.log(data);
            var list = JSON.parse(data);
            var bQueueE = $('.dx-back-q .dx-queue').first();
            var bBillE = $(sessionStorage.getItem("dx-bill"));
            bQueueE.empty();
            for (var i = 0; i < list.length; i++) {
                var bill = list[i];
                var e = bBillE.clone();
                e.find('.dx-field[buyPrice]').html((bill.buyPrice / 100.00).toFixed(2));
                e.find('.dx-field[odds]').html(bill.odds);
                e.find('.dx-field[costs]').html(parseFloat(web3.utils.fromWei(bill.costs, 'ether')).toFixed(6));
                e.find('.dx-field[player]').html(bill.player);
                bQueueE.append(e);
            }
        })
    }
    refreshDealPanel();

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
            var price = (obj.bulletinBoard.price / 100.00).toFixed(2);
            $('.dx-buy-price li[price] input[price]').val(price);
            $('.dx-header li[broker] span').html(obj.broker);
            var panel = $('.dx-panel');
            panel.find('.dx-dts[frontQueueCount] span').html(obj.frontQueueCount);
            panel.find('.dx-dts[backQueueCount] span').html(obj.backQueueCount);
            panel.find('.dx-dts[balance] span').html(obj.balance);
            panel.find('.dx-dts[queueCount] span').html(obj.queueCount);
            panel.find('.dx-dts[isRunning] span').html(obj.isRunning == true ? '正在运行' : '停止');
            panel.find('.dx-dts[price] span').html(price);
            panel.find('.dx-dts[exchangeRate] span').html(obj.exchangeRate);
            panel.find('.dx-dts[kickbackRate]>span').html(obj.bulletinBoard.kickbackRate / 100);
            panel.find('.dx-dts[kickbackRate] li[brokerageRate] span').html(obj.bulletinBoard.brokerageRate / 100);
            panel.find('.dx-dts[kickbackRate] li[taxRate] span').html(obj.bulletinBoard.taxRate / 100);
            panel.find('.dx-dts[total] li[funds] span').html(web3.utils.fromWei(obj.bulletinBoard.funds, 'ether'));
            panel.find('.dx-dts[total] li[odds] span').html(obj.bulletinBoard.odds);
            $('#bulletinBoard').val(JSON.stringify(obj.bulletinBoard));
        })
    }
    refreshDetails();
    $('.dx-box .dx-layout .dx-left .dx-panel .dx-dts[matchmake] span').click(function () {
        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }
        var the = $(this);
        var p = the.parents('.dx-dts[matchmake]').find('p');
        p.empty();
        $.get('/api/oddsdex.matchmake', { address: contractAddress }, function (data) {
            console.log(data);
            var obj = JSON.parse(data);
            var winD = '未定';
            switch (obj.winningDirection) {
                case 1:
                    winD = '正面赢';
                    break;
                case 2:
                    winD = '背面赢';
                    break;
            }
            p.html("<i><label>撮合次数：" + obj.matchmakeTimes + "</label></i><i><label>赢方：" + winD + "</label></i>");
            p.show();
            refreshDetails();
            refreshDealPanel();
        })
    });
    $('.dx-box .dx-panel .dx-dts[balance] span').click(async function () {
        var input = prompt("输入金额ether", "0.1");
        if (input == null) {
            return;
        }
        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }
        var broker = $('.dx-box .dx-header li[broker] span').html();
        const amountWei = web3.utils.toWei(input, "ether");
        const transaction = {
            from: broker,
            to: contractAddress,
            value: amountWei,
            data: web3.eth.abi.encodeFunctionSignature('recharge()')
            // nonce: Math.floor((Math.random()*100000)+1)
        };
        // Send the transaction
        try {
            const result = await web3.eth.sendTransaction(transaction);
            refreshDetails();
            refreshDealPanel();
            console.log("Transaction result:", result);
        } catch (err) {
            // Handle error
            console.error("Failed to send transaction:", err);// Update status
        }
    })
    $('.dx-buy-price li[up] a').click(function () {
        var e = $('.dx-buy-price li[price] input[price]');
        var priceStr = e.val();
        if (priceStr == '') {
            alert('价格为空');
            return;
        }
        var price = parseFloat(priceStr);
        price = price + 0.02;
        e.val(price.toFixed(2));
        refreshPayment();
    })
    $('.dx-buy-price li[down] a').click(function () {
        var e = $('.dx-buy-price li[price] input[price]');
        var priceStr = e.val();
        if (priceStr == '') {
            alert('价格为空');
            return;
        }
        var price = parseFloat(priceStr);
        price -= 0.02;
        e.val(price.toFixed(2));
        refreshPayment();
    })
    $('.dx-buy-price li[price] input[price]').change(function () {
        refreshPayment();
    })
    $('.dx-box .dx-buy-lucky>a[gen]').click(function () {
        var v1 = Math.floor(Math.random() * 9);
        var v2 = Math.floor(Math.random() * 9);
        var v3 = Math.floor(Math.random() * 9);
        var v4 = Math.floor(Math.random() * 9);
        var v5 = Math.floor(Math.random() * 9);
        var v6 = Math.floor(Math.random() * 9);
        var randomNum = v1 + '' + v2 + '' + v3 + '' + v4 + '' + v5 + '' + v6;
        var numberSpan = $('.dx-box .dx-buy-lucky>span[number]');
        numberSpan.html(randomNum);
        numberSpan.attr('number', randomNum);
    });
    $('.dx-box .dx-buy-lucky>a[gen]').trigger('click');

    $('.dx-box .dx-buy-lucky>span[number]').click(function () {
        var input = prompt('请输入幸运数字');
        if (input == null || input == '') {
            return;
        }
        if ((input + '').length != 6) {
            alert('幸运数字至少是6个数字');
            return;
        }
        parseInt(input);
        var numberSpan = $('.dx-box .dx-buy-lucky>span[number]');
        numberSpan.html(input);
        numberSpan.attr('number', input);
    })

    $('.dx-box .dx-buy-odds input[odds]').change(function () {
        refreshPayment();
    });
    function refreshPayment() {
        var odds = parseInt($('.dx-box .dx-buy-odds input[odds]').val());
        if (odds < 10) {
            alert('至少要买一手，一手为10个odds');
            $(this).val('10');
            $(this).trigger('change');
            return;
        }
        var inputPriceStr = $('.dx-buy-price-input input[price]').val();
        if (inputPriceStr == '') {
            return;
        }
        var json = $('#bulletinBoard').val();
        var bulletinBoard = JSON.parse(json);
        var wei = odds * (parseFloat(inputPriceStr) * 100) * bulletinBoard.oddunit;
        var eth = web3.utils.fromWei(wei, 'ether');
        var v = parseFloat(eth).toFixed(6);
        $('.dx-box .dx-buy-odds span[funds]').html(v);
    }
    $('.dx-box .dx-buy-button a').click(async function () {
        var oddsV = $('.dx-box .dx-buy-odds input[odds]').val();
        if (oddsV == '') {
            alert('请输入购买odds的数量');
            return;
        }
        var buyPriceV = $('.dx-box .dx-buy-price input[price]').val();
        if (buyPriceV == '') {
            return;
        }

        var json = $('#bulletinBoard').val();
        var bulletinBoard = JSON.parse(json);

        var payableWei = parseInt(oddsV) * (parseFloat(buyPriceV) * 100) * bulletinBoard.oddunit;
        var payableEth = parseFloat(web3.utils.fromWei(payableWei, 'ether')).toFixed(6);
        $('.mask .dialog p[amount] span').html(payableEth);
        $('.mask .dialog p[amount]').attr('amount', payableEth);
        const accounts = await web3.eth.requestAccounts();
        var selectE = $('.mask .dialog select');
        selectE.empty();
        selectE.append("<option value='@@'>选择付款账户</option>");
        for (var i = 0; i < accounts.length; i++) {
            var account = accounts[i];
            selectE.append("<option value='" + account + "'>" + account + "</option>");
        }
        $('.mask').show();

    });

    $('.mask .dialog ul[ops] li[yes] a').click(async function () {
        var oddsV = $('.dx-box .dx-buy-odds input[odds]').val();
        if (oddsV == '') {
            alert('请输入购买odds的数量');
            return;
        }
        var luckyNumberV = $('.dx-box .dx-buy-lucky span[number]').attr('number');
        var directionV = $('.dx-box .dx-buy-sel .dx-direction input[name="direction"]:checked').val();
        var selectAccount = $('.mask .dialog select').val();
        if (typeof selectAccount == 'undefined' || selectAccount == '' || '@@' == selectAccount) {
            alert('没有选择账号');
            return;
        }
        var buyPriceV = $('.dx-box .dx-buy-price input[price]').val();
        if (buyPriceV == '') {
            return;
        }
        // alert(selectAccount+' '+oddsV + ' ' + luckyNumberV + ' ' + directionV);

        var params = new URLSearchParams(window.location.search)
        var contractAddress = params.get('address');
        if (typeof contractAddress == 'undefined') {
            alert('address is null');
            return;
        }

        var json = $('#bulletinBoard').val();
        var bulletinBoard = JSON.parse(json);
        var payableWei = parseInt(oddsV) * parseInt(parseFloat(buyPriceV) * 100) * bulletinBoard.oddunit;
        // var paymethod = 'stake(CoinDirection,uint32)';
        var paymethod = web3.eth.abi.encodeFunctionCall({
            name: 'stake',
            type: 'function',
            inputs: [{
                type: 'uint256',
                name: 'buyPrice'
            }, {
                type: 'uint8',
                name: 'buyDirection'
            }, {
                type: 'uint32',
                name: 'luckyNumber'
            }]
        }, [parseInt(parseFloat(buyPriceV) * 100), parseInt(directionV), parseInt(luckyNumberV)]);

        const transaction = {
            from: selectAccount,
            to: contractAddress,
            value: payableWei,
            data: paymethod
        };
        // Send the transaction
        var result;
        try {
            result = await web3.eth.sendTransaction(transaction);
            $('.mask').hide();
        } catch (err) {
            // Handle error
            $('.mask .dialog p[tips] span').html(err);
            console.log("Failed to send transaction:" + err);// Update status
            return;
        }
    });

    $('.mask .dialog ul[ops] li[no] a').click(function () {
        $('.mask').hide();
    });
});