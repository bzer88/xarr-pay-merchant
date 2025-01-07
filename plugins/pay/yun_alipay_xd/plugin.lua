-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")
local orderPayHelper = require("orderPayHelper")

PAY_CHANNEL_CODE_YUN_ALIPAY_XD = "yun_alipay_xd"
--- 插件信息
plugin = {
    info = {
        name = PAY_CHANNEL_CODE_YUN_ALIPAY_XD,
        title = '支付宝-XD',
        author = '闲蛋网',
        description = "支付宝-XD",
        link = 'https://www.xdau.cn/',
        version = "1.0.2",
        -- 最小支持主程序版本号
        min_main_version = "1.3.8",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '扫码免挂',
                    value = PAY_CHANNEL_CODE_YUN_ALIPAY_XD,
                    options = {
                        -- 使用递增金额
                        use_add_amount = 1,
                        -- 使用二维码登录流程
                        use_qrcode_login = 1
                    }
                },
            },
        },
        options = {
            -- 启动定时查询在线状态
            detection_interval = 3,
            detection_type = "cron", --- order 单订单检查 cron 定时执行任务
            -- 配置项
            --options = {
            --    {
            --        title = "云端地址", placeholder = "多个以英文逗号[,]分割", key = "host", default = "https://api.xxx.com"
            --    },
            --}
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
                name = 'gateway',
                label = '选择网关',
                type = 'select',
                default = "",
                options = {
                    tip = '',
                },
                placeholder = "请选址网关",
                options = {
                    -- 选择网关
                    chose_gateway = 1,
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请选择",
                    }
                }
            },
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
            {
                name = 'bind_token',
                label = '绑定的用户信息',
                type = "input",
                hidden = 1,
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

-- 定时任务
function plugin.cron(pAccountInfo, pPluginOptions)
    local vAccountInfo = json.decode(pAccountInfo)
    local vParams = json.decode(vAccountInfo.options)
    if vParams.bind_token == nil or vParams.bind_token == "" then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = "未登录"
        })
    end

    local bindTokeInfo = json.decode(vParams.bind_token)

    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vParams.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end
    local apiUri = string.format('%s/Alipay_Frame/IsLoginStatus', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", bindTokeInfo.uid),
        timeout = "30s",

    })
    if error_message ~= nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end

    if returnInfo.code ~= "1" then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        if returnInfo.code == "0" then
            return json.encode({
                err_code = 201,
                err_message = "请扫描二维码登录"
            })
        end
        if returnInfo.code == "-1" then
            return json.encode({
                err_code = 500,
                err_message = "uid参数错误"
            })
        end
        if returnInfo.code == "-2" then
            return json.encode({
                err_code = 500,
                err_message = "没有找到Uid"
            })
        end

        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    -- 如果离线状态 则设置为在线
    if vAccountInfo.online ~= 1 then
        -- 设置在线
        helper.channel_account_online(vAccountInfo.id)
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('在线')
    })

end


-- 二维码登录
function plugin.login_qrcode(pAccountInfo, pUserInfo, pParams)
    local vParams = json.decode(pParams)
    local vUserInfo = json.decode(pUserInfo)

    local vAccountInfo = json.decode(pAccountInfo)
    local vAccountOption = json.decode(vAccountInfo.options)
    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vAccountOption.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end

    -- 1. 创建客户端
    local apiUri = string.format('%s/Alipay_Frame/CreateID', serverAddress)
    local req = {
        ["data"] = helper.base64_encode(json.encode({ ["site"] = vParams['domain_url'], ["pid"] = vUserInfo.id, ["key"] = vUserInfo.app_secret }))
    }

    print("请求地址",apiUri,"请求内容",funcs.table_http_query(req))

    local response, error_message = http.request("POST", apiUri, {
        query = funcs.table_http_query(req),
        timeout = "30s",

    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    print("创建客户端返回内容",response.body)
    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end
    if returnInfo.code ~= "1" then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态码 响应内容: %v', response.body)
        })
    end

    local uid = returnInfo.uid


    -- 2. 获取登录二维码
    apiUri = string.format('%s/Alipay_Frame/QRCode', serverAddress)
    response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", uid),
        timeout = "30s",
    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求获取登录二维码错误: %v', error_message)
        })
    end

    returnInfo = json.decode(response.body)
    print("创建二维码返回内容",response.body)
    if returnInfo.code ~= "1" then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    return json.encode({
        -- 返回二维码
        qrcode = returnInfo.url,
        -- 返回二维码相关参数 check 会一并携带返回
        options = {
            uid = uid
        },
        err_code = 200,
        err_message = ""
    })

end


-- 检查二维码登录状态
function plugin.login_qrcode_check(pAccountInfo, pUserInfo, pParams)
    local vParams = json.decode(pParams)
    local vAccountInfo = json.decode(pAccountInfo)
    local vAccountOption = json.decode(vAccountInfo.options)
    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vAccountOption.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end
    local apiUri = string.format('%s/Alipay_Frame/IsLoginStatus', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", vParams.uid),
        timeout = "30s",

    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end
    if returnInfo.code ~= "1" then
        if returnInfo.code == "0" then
            return json.encode({
                err_code = 201,
                err_message = "请扫描二维码登录"
            })
        end
        if returnInfo.code == "-1" then
            return json.encode({
                err_code = 500,
                err_message = "uid参数错误"
            })
        end
        if returnInfo.code == "-2" then
            return json.encode({
                err_code = 500,
                err_message = "没有找到Uid"
            })
        end

        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('登录成功')
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