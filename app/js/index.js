$(document).ready(async function () {
    const web3 = new Web3(window.ethereum);

    $('.ix-factory ul li[withdraw] a').click(function () {
        $.get('/api/factory.withdraw', {}, function (data) {
            refreshBalance();
        });
    })

    $('.ix-box .ix-form li[req] a').click(async function () {
        var fee = $('.ix-form li[amount]').attr('amount');
        if (typeof fee == "undefined" || fee == '') {
            alert('费用为空');
            return;
        }
        var contractAddress = $('.ix-form li[amount]').attr('contractAddress');
        if (typeof contractAddress == "undefined" || contractAddress == '') {
            alert('合约地址为空');
            return;
        }
        var payMode = $('.ix-pay input[name="payMode"]:checked').val();
        $('.mask .dialog p[amount]').attr('amount', fee);
        $('.mask .dialog p[amount]').attr('contractAddress', contractAddress);
        $('.mask .dialog p[amount]').attr('payMode', payMode);
        $('.mask .dialog p[amount] span').html(fee);
        const accounts = await web3.eth.requestAccounts();
        var selectE = $('.mask .dialog select');
        selectE.empty();
        selectE.append("<option value='@@'>选择付款账户</option>");
        for (var i = 0; i < accounts.length; i++) {
            var account = accounts[i];
            selectE.append("<option value='" + account + "'>" + account + "</option>");
        }
        $('.mask .dialog p[tips] span').empty();
        $('.mask').attr('itfor', 'create');
        $('.mask').show();
        tempAmountE = $('.ix-form li[amount]').clone();
    });

    function refreshPayPanel() {
        var payMode = $('.ix-pay input[name="payMode"]:checked').val();
        if (typeof payMode == "undefined" || payMode == '') {
            return;
        }
        $('.ix-form li[amount] span').html('...');
        $.get('/api/factory.getFeeInfo', { payMode: payMode }, function (data) {
            console.log(data);
            var obj = JSON.parse(data);
            $('.ix-form li[amount] span').html(obj.fee + '');
            $('.ix-form li[amount]').attr('amount', obj.fee + '');
            $('.ix-form li[amount]').attr('contractAddress', obj.address + '');
        });
    }
    refreshPayPanel();
    $('.ix-pay input[name="payMode"]').change(function () {
        refreshPayPanel();
    });

    function refreshBalance() {
        $.get('/api/factory.getBalance', {}, function (data) {
            console.log(data);
            $('.ix-factory li[balance] span').html(data);
        });
    }
    refreshBalance();

    $('.mask ul[ops] li[no] a').click(function () {
        $('.mask').hide();
    });

    $('.ix-box').undelegate('.mask[itfor="create"] .dialog ul[ops] li[yes]', 'click');
    $('.ix-box').delegate('.mask[itfor="create"] .dialog ul[ops] li[yes]', 'click', async function () {
        var isValidBroker = $('.mask[itfor="create"] .dialog p[amount]').attr('isValidBroker');
        var broker = $('.mask .dialog select').val();
        if ('@@' == broker) {
            return;
        }
        if ("true" == isValidBroker) {
            createOdds(broker);
            return;
        }
        await payment(broker);
        createOdds(broker);
    });

    async function payment(broker) {
        var amount = $('.mask .dialog p[amount]').attr('amount');
        if (typeof amount == "undefined" || amount == '') {
            alert('金额为空');
            return;
        }
        var contractAddress = $('.mask .dialog p[amount]').attr('contractAddress');
        if (typeof contractAddress == "undefined" || contractAddress == '') {
            alert('合约地址为空');
            return;
        }
        var payMode = $('.mask .dialog p[amount]').attr('payMode');
        if (typeof payMode == "undefined" || payMode == '') {
            alert('付款方式为空');
            return;
        }

        const amountWei = web3.utils.toWei(amount, "ether");
        const transaction = {
            from: broker,
            to: contractAddress,
            value: amountWei,
            // nonce: Math.floor((Math.random()*100000)+1)
        };
        switch (payMode) {
            case '1':
                break;
            case '2':
                transaction.data = web3.eth.abi.encodeFunctionSignature('recMothlyFee()');
                break;
        }
        // Send the transaction
        var result;
        try {
            result = await web3.eth.sendTransaction(transaction);
            $('.mask').hide();
            refreshBalance();
        } catch (err) {
            // Handle error
            $('.mask .dialog p[tips] span').html(err);
            console.error("Failed to send transaction:", err);// Update status
            return;
        }
    }
    function createOdds(broker) {
        $.get('/api/factory.create', { broker: broker }, function (data) {
            var obj = JSON.parse(data);
            $('.ix-create .bb-details').append("<li>" + obj.contractAddress + "</li>");
            $('.ix-broker select').empty();
            $('.ix-broker select').append('<option value="@@">未选择</option>');
            $('.mask').hide();
            refreshBrokerList();
        });
    }

    $('.ix-box').undelegate('.mask[itfor="create"] .dialog select', 'change');
    $('.ix-box').delegate('.mask[itfor="create"] .dialog select', 'change', function () {
        var broker = $(this).val();
        if ('@@' == broker) {
            return;
        }
        $.get('/api/factory.isValidBroker', { broker: broker }, function (data) {
            var isValidBroker = 'true' == data;
            var amountE = $('.mask[itfor="create"] .dialog p[amount]');
            amountE.attr('isValidBroker', isValidBroker);
            if (isValidBroker) {
                amountE.empty();
                amountE.append("<span style='font-size:12px !important;'>所选账户已是有效的付费会员，点确认按钮不会扣款</span>");
            } else {
                amountE.empty();
                amountE.append("你需支付注金" + tempAmountE.html());
            }
        });
    });
    function refreshBrokerList() {
        $('.ix-box .ix-contracts .ix-list').hide();
        $.get('/api/factory.brokers', {}, function (data) {
            console.log(data);
            var arr = JSON.parse(data);
            for (var i = 0; i < arr.length; i++) {
                var address = arr[i];
                $('.ix-broker select').append("<option value='" + address + "'>" + address + "</option>");
            }
        });
    }
    refreshBrokerList();
    $('.ix-broker select').change(function () {
        var selector = $(this);
        var broker = selector.val();
        $.get('/api/factory.contracts', { broker: broker }, function (data) {
            console.log(data);
            var arr = JSON.parse(data);
            var ul = $('.ix-list');
            var li = ul.find('>li').first().clone();
            ul.empty();
            for (var i = 0; i < arr.length; i++) {
                var address = arr[i];
                var ali = li.clone();
                ali.find('label').html((i + 1) + '');
                ali.find('a').html(address);
                ali.find('a').attr('href','./pages/oddsdex/index?address='+address)
                ali.find('a').attr('target','_blank');
                ul.append(ali);
            }
            if (arr.length > 0) {
                $('.ix-box .ix-contracts .ix-list').show();
            } else {
                $('.ix-box .ix-contracts .ix-list').hide();
            }
        });
    });

});