-- 载入插件
local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderPayHelper = require("orderPayHelper")

PAY_ALIPAY_BILL = "alipay_bill"

--- 插件信息
plugin = {
    info = {
        name = PAY_ALIPAY_BILL,
        title = '支付宝-商家账单',
        author = '包子',
        description = "支付宝官方账单",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '商家账单',
                    value = PAY_ALIPAY_BILL,
                    options = {
                        use_add_amount = 1,
                    }
                },
            },

        },
        options = {
            detection_interval = 3,
            detection_type = "cron", --- order 单订单检查 cron 定时执行任务
        },

    }
}

function plugin.pluginInfo()
    return json.encode(plugin.info)
end

-- 获取form表单
function plugin.formItems(payType, payChannel)
    return json.encode({
        inputs = {
            {
                name = 'qrcode',
                label = '收款码地址',
                type = 'input',
                default = "",
                options = {
                    tip = '',
                },
                placeholder = "请输入收款码地址",
                when = "this.formModel.options.type == 'qrcode'",
                options = {
                    append_deqrocde = 1, -- 增加解析二维码功能
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'qrcode_file',
                label = '收款码图片',
                type = 'image',
                default = "",
                options = {
                    tip = '',
                },
                placeholder = "请上传收款码图片",
                when = "this.formModel.options.type == 'image'",
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'pid',
                label = 'PID',
                type = 'input',
                default = "",
                options = {
                    tip = '',
                },
                placeholder = "请输入PID",
                when = "this.formModel.options.type == 'pid'",
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'qrcode_mod',
                label = '二维码模式',
                type = 'select',
                default = "9",
                options = {
                    tip = '',
                },
                placeholder = "请选择二维码模式",
                when = "this.formModel.options.type == 'pid'",
                values = {
                    {
                        label = "模式9",
                        value = "9"
                    },
                    {
                        label = "模式10",
                        value = "10"
                    },

                    {
                        label = "模式11",
                        value = "11"
                    },
                    {
                        label = "转账确认单",
                        value = "12"
                    },
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'type',
                label = '收款码类型',
                type = 'select',
                default = "qrcode",
                options = {
                    tip = '',
                },
                placeholder = "请选择收款码类型",
                values = {
                    {
                        label = "二维码",
                        value = "qrcode"
                    },
                    {
                        label = "二维码图片",
                        value = "image"
                    },
                    {
                        label = "PID",
                        value = "pid"
                    },
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'app_id',
                label = '应用ID',
                type = 'input',
                default = "",
                placeholder = "请输入应用ID",
                options = {
                    tip = '',
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入"
                    }
                }
            },
            {
                name = 'app_secret',
                label = '应用私钥',
                type = 'textarea',
                default = "",
                hidden_list = 1,
                placeholder = "请输入应用私钥",
                options = {
                    tip = '',
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入"
                    }
                }
            },

            {
                name = 'scan_type',
                label = '订单检查方式',
                type = 'radio',
                default = "order_or_amount",
                options = {
                    tip = '',
                },
                placeholder = "请选择订单检查方式",
                values = {
                    {
                        label = "订单号匹配不到则使用金额",
                        value = "order_or_amount"
                    },
                    {
                        label = "订单号",
                        value = "order"
                    },

                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
            {
                name = 'order_temp_amount',
                label = '取消订单递增金额',
                type = 'radio',
                default = "0",
                options = {
                    tip = '<b>注意:</b>订单检查方式为订单号的时候才能选择[是]',
                },
                placeholder = "请选择订单检查方式",
                values = {
                    {
                        label = "否",
                        value = "0"
                    },
                    {
                        label = "是",
                        value = "1"
                    },

                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入",
                    }
                }
            },
        },
    })
end

function plugin.create(pOrderInfo, pluginOptions, ...)
    local args = { ... }
    local orderInfoDe = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)

    if options['type'] == 'image' then
        return json.encode({
            type = "qrcode",
            qrcode_file = options['qrcode_file'],
            url = "",
            content = "",
            out_trade_no = '',
            err_code = 200,
            err_message = ""
        })

    elseif options['type'] == 'pid' then
        if options['qrcode_mod'] == '9' then
            return json.encode({
                type = "qrcode",
                qrcode = "https://ds.alipay.com/?from=pc&appId=20000116&actionType=toAccount&goBack=NO&amount=" .. orderInfoDe.trade_amount_str .. "&userId=" .. options['pid'] .. "&memo=" .. orderInfoDe.order_id,
                url = "",
                content = "",
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        elseif options['qrcode_mod'] == '10' then
            return json.encode({
                type = "qrcode",
                qrcode_use_short_url = 1,
                qrcode = "alipayqr://platformapi/startapp?saId=20000032&url=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D20000123%26actionType%3Dscan%26biz_data%3D%257B%2522s%2522%253A%2522money%2522%252C%2522u%2522%253A%2522" .. options['pid'] .. "%2522%252C%2522a%2522%253A%2522" .. orderInfoDe.trade_amount_str .. "%2522%252C%2522m%2522%253A%2522" .. orderInfoDe.order_id .. "%2522%257D",
                url = "",
                content = "",
                scheme = "alipayqr://platformapi/startapp?saId=20000032&url=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D20000123%26actionType%3Dscan%26biz_data%3D%257B%2522s%2522%253A%2522money%2522%252C%2522u%2522%253A%2522" .. options['pid'] .. "%2522%252C%2522a%2522%253A%2522" .. orderInfoDe.trade_amount_str .. "%2522%252C%2522m%2522%253A%2522" .. orderInfoDe.order_id .. "%2522%257D",
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        elseif options['qrcode_mod'] == '11' then
            return json.encode({
                type = "html",
                qrcode_use_short_url = 1,
                url = "",
                content = plugin.buildMod11Html(options['pid'], orderInfoDe.trade_amount_str, orderInfoDe.order_id),
                scheme = "alipays://platformapi/startapp?appId=20000067&url="..helper.url_encode("https://render.alipay.com/p/s/i?scheme="..helper.url_encode("alipays://platformapi/startapp?appId=20000180&url="..helper.url_encode(orderPayHelper.get_toapp_url(orderInfoDe.order_id,orderInfoDe.host)))),
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })

        elseif options['qrcode_mod'] == '12' then
            return json.encode({
                type = "html",
                qrcode_use_short_url = 1,
                url = "",
                content = plugin.buildMod12Html(options['pid'], orderInfoDe.trade_amount_str, orderInfoDe.order_id),
                scheme = "alipays://platformapi/startapp?appId=20000067&url=" .. helper.url_encode("https://render.alipay.com/p/s/i?scheme=" .. helper.url_encode("alipays://platformapi/startapp?appId=20000180&url=" .. helper.url_encode(orderPayHelper.get_toapp_url(orderInfoDe.order_id, orderInfoDe.host)))),
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        end
    end

    return json.encode({
        type = "qrcode",
        qrcode = options['qrcode'],
        url = "",
        scheme = "alipays://platformapi/startapp?appId=20000067&url="..helper.url_encode("https://render.alipay.com/p/s/i?scheme="..helper.url_encode("alipays://platformapi/startapp?appId=20000180&url="..helper.url_encode(orderPayHelper.get_toapp_url(orderInfoDe.order_id,orderInfoDe.host)))),
        content = "",
        out_trade_no = '',
        err_code = 200,
        err_message = ""
    })

end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    return json.encode({
        error_code = 500,
        error_message = "暂不支持",
        response = "",
    })
end

-- 定时任务
function plugin.cron(pAccountInfo, pPluginOptions)
    local accountInfo = json.decode(pAccountInfo)
    local options = json.decode(pPluginOptions)

    ---- 获取支付宝订单列表
    local err_code, err_message, list = orderPayHelper.alipay_bill_list(pPluginOptions)
    if err_code ~= 200 then
        return json.encode({
            err_code = err_code,
            err_message = err_message
        })
    end
    local orderList = json.decode(list)

    ---- 录入数据
    for _, v in ipairs(orderList) do
        local amount = helper.amount_str2int(v.trans_amount)
        if v.direction ~= "收入" or amount <= 0 then
            goto continue
        end

        -- 判断第三方订单是否存在
        local exist = orderPayHelper.third_order_exist({
            pay_type = "alipay",
            channel_code = PAY_ALIPAY_BILL,
            uid = accountInfo.uid,
            account_id = accountInfo.id,
            third_account = options['app_id'],
            third_order_id = v.alipay_order_no
        })
        if exist then
            goto continue
        end

        if v.trans_memo then
            v.trans_memo = string.gsub(v.trans_memo, "请勿添加备注-", "")
        end
        local matched, matchGroups =  helper.regexp_match_group(v.trans_memo, "^(?<order_id>\\d{20})$")
        local out_order_id = ""
        if matched then
            matchGroups = json.decode(matchGroups)
            if matchGroups["order_id"] then
                print(matchGroups["order_id"][1],"正则数据4")

                out_order_id = matchGroups["order_id"][1]
            end
        end

        print("识别外部订单号,准备插入",v.alipay_order_no,out_order_id)


        -- 录入数据
        local insertId = orderPayHelper.third_order_insert({
            pay_type = "alipay",
            channel_code = PAY_ALIPAY_BILL,
            uid = accountInfo.uid,
            account_id = accountInfo.id,

            ["buyer_id"] = "",
            ["buyer_name"] = v.other_account,
            third_order_id = v.alipay_order_no,
            third_account = options['app_id'],
            ["amount"] = helper.amount_str2int(v.trans_amount),
            ["remark"] = v.trans_memo,
            ["trans_time"] = helper.datetime_to_timestamp(v.trans_dt),
            ["type"] = v.type,
            ["out_order_id"] = out_order_id,

        })

        -- 录入失败
        if insertId <= 0 then
            print("外部订单插入失败",v.alipay_order_no,out_order_id)
            goto continue
        end

        -- 录入成功
        err_code, err_message = orderPayHelper.third_order_report(insertId)
        if err_code == 200 then
            print("订单上报成功:" .. err_message,v.alipay_order_no,out_order_id,v.trans_amount)
        else
            print("订单上报失败:" .. err_message,v.alipay_order_no,out_order_id,v.trans_amount)
        end

        -- 尾部
        :: continue ::
    end

    return json.encode({
        err_code = 200,
        err_message = "处理完成"
    })

end

function plugin.buildMod11Html (pid, money, order_id)
    return [[<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>收银台</title>
    <script src="//gw.alipayobjects.com/as/g/h5-lib/alipayjsapi/3.1.1/alipayjsapi.min.js"></script>
</head>
<body>
<script>
    var userId = "]] .. pid .. [[";
    var money = "]] .. money .. [[";
    var remark = "]] .. order_id .. [[";

    function returnApp() {
        AlipayJSBridge.call("exitApp")
    }

    function ready(a) {
        window.AlipayJSBridge ? a && a() : document.addEventListener("AlipayJSBridgeReady", a, !1)
    }

    ready(function () {
        try {
            var a = {
                actionType: "scan",
                u: userId,
                a: money,
                m: remark,
                biz_data: {
                    s: "money",
                    u: userId,
                    a: money,
                    m: remark
                }
            }
        } catch (b) {
            returnApp()
        }
        AlipayJSBridge.call("startApp", {
            appId: "20000123",
            param: a
        }, function (a) { })
    });
    document.addEventListener("resume", function (a) {
        returnApp()
    });
</script>
</body>
</html>]]
end

function plugin.buildMod12Html (pid, money, order_id)
    local url = string.format("https://render.alipay.com/p/yuyan/180020010001206672/rent-index.html?formData=%s", helper.url_encode(json.encode({
        productCode = "TRANSFER_TO_ALIPAY_ACCOUNT",
        bizScene = "YUEBAO",
        outBizNo = "",
        transAmount = money,
        remark = order_id,
        businessParams = {
            returnUrl = "alipays://platformapi/startApp?appId=20000218&bizScenario=transoutXtrans"
        },
        payeeInfo = {
            identity = pid,
            identityType = "ALIPAY_USER_ID"
        }
    }
    )))
    return [[<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>收银台</title>
    <script src="//gw.alipayobjects.com/as/g/h5-lib/alipayjsapi/3.1.1/alipayjsapi.min.js"></script>
</head>
<body>
<script>
    var userId = "]] .. pid .. [[";
    var money = "]] .. money .. [[";
    var remark = "]] .. order_id .. [[";

     AlipayJSBridge.call('setTitleColor', {
        color: parseInt('1959c1', 16),
        reset: false
    });
    AlipayJSBridge.call('showTitleLoading');
    AlipayJSBridge.call('setTitle', {
        title: '请稍等..',
        subtitle: 'XArrPay正在检测支付环境..'
    });
    AlipayJSBridge.call('setOptionMenu', {
        icontype: 'filter',
        redDot: '02',
    });
    AlipayJSBridge.call('showOptionMenu');
    document.addEventListener('optionMenu', function(e) {
        AlipayJSBridge.call('showPopMenu', {
            menus: [{
                name: '查看帮助',
                tag: 'tag1',
                redDot: ''
            }, {
                name: 'XArrPay',
                tag: 'tag2',
            }],
        }, function(e) {
            console.log(e)
        })
    }, false);

    AlipayJSBridge.call("pushWindow", {
        url: ']] .. url .. [[',
        param: {
            showToolBar: "NO"
        }
    });



</script>
</body>
</html>]]
end
