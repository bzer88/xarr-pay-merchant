-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")

--- 插件信息
plugin = {
    info = {
        name = 'jeequan_plus',
        title = '计全Plus',
        author = '官方',
        description = "计全Plus插件",
        link = "https://www.jeequan.com/",
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            bank = {
                {
                    label = '计全Plus',
                    value = 'bank_jeequan_plus',
                    -- 绑定支付方式
                    bind_pay_type = { "alipay", "wxpay", "bank" },
                },
            },
        },
        options = {
            callback = 1,
            detection_interval = 0,
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
                label = '支付网关',
                type = 'input',
                default = "https://pay.dianlaibaopay.cn",
                placeholder = "",
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
                name = 'mchNo',
                label = '商户号',
                type = 'input',
                default = "",
                placeholder = "",
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
                name = 'appId',
                label = '应用ID',
                type = 'input',
                default = "",
                placeholder = "",
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
                name = 'appSecret',
                label = '密钥',
                type = 'input',
                default = "",
                placeholder = "",
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

        },
    })
end

function plugin.create(pOrderInfo, pluginOptions, ...)
    local args = { ... }

    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)

    local mchNo = options['mchNo']
    local appId = options['appId']
    local appSecret = options['appSecret']
    local gateway = options['gateway']


    -- 组装提交请求
    local req = {
        ["amount"] = orderInfo['trade_amount'],
        ["extParam"] = "",
        ["mchOrderNo"] = orderInfo['order_id'],
        ["subject"] = orderInfo['subject'],
        ["wayCode"] = "QR_CASHIER",
        ["reqTime"] = orderInfo['timestamp'],
        ["body"] = orderInfo['subject'],
        ["version"] = "1.0",
        --["channelExtra"] = json.encode({ ["payDataType"] = "codeUrl" }),
        ["appId"] = appId,
        ["clientIp"] = orderInfo['client_ip'],
        ["notifyUrl"] = orderInfo['notify_url'],
        ["signType"] = "MD5",
        ["currency"] = "cny",
        ["returnUrl"] = orderInfo['return_url'],
        ["mchNo"] = mchNo,
        ["divisionMode"] = 1,
    }
    --if pOrderInfo['pay_type'] == 'alipay' then
    --    req.wayCode = "ALI_QR"
    --elseif pOrderInfo['pay_type'] == 'wxpay' then
    --    req.wayCode = "WX_NATIVE"
    --else
    --    req.wayCode = "WEB_CASHIER"
    --end

    req["sign"] = plugin._getSign(req, "&key=" .. appSecret)

    local res = ""
    local error_message = nil
    local response = {}

    print("[插件][计全] 请求内容" .. funcs.table_http_query(req))
    local uri = gateway .. "/api/pay/unifiedOrder"

    local params = {
        query = "",
        body = funcs.table_http_query(req),
        form = "",
        timeout = "30s",
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded"
        }
    }

    response, error_message = http.request("POST", uri, params)
    if response and response.body then
        res = response.body
    end

    print("[插件][计全] 返回内容" .. res)
    local returnInfo = json.decode(res)

    if returnInfo == nil then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = '请求响应错误 返回内容:' .. res
        })
    end

    if returnInfo['code'] ~= 0 then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = returnInfo['msg']
        })
    end


    return json.encode({
        type = "qrcode",
        qrcode = returnInfo.data.payData,
        url = "",
        content = "",
        out_trade_no = returnInfo.data.payOrderId,
        err_code = 200,
        err_message = ""
    })


end

-- 支付回调
function plugin.notify(pRequest, pOrderInfo, pParams, pluginOptions)
    local request = json.decode(pRequest)
    local params = json.decode(pParams)
    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)

    -- 判断请求方式
    local reqData = ""
    if request['method'] == 'POST' then
        reqData = (request['body'])
    else
        reqData = (request['query'])
    end

    -- 获取签名内容
    local sign = plugin._getSign(reqData, "&key="..options['appSecret'])
    if string.upper(sign) == string.upper(reqData['sign']) then
        -- 签名校验成功
        if reqData['mchNo'] ~= options['mchNo'] then
            return json.encode({
                error_code = 500,
                error_message = "交易商户号异常"
            })
        end

        if reqData['state'] ~= "2" then
            return json.encode({
                error_code = 500,
                error_message = "交易未完成"
            })
        end

        -- 商户订单号
        local out_trade_no = reqData['mchOrderNo']
        -- 外部系统订单号
        local trade_no = reqData['payOrderId']
        -- 避免精度有问题
        local money = math.floor((reqData['amount'] + 0.000005) )

        -- 通知订单处理完成
        local err_code, err_message, response = orderHelper.notify_process(json.encode({
            out_trade_no = trade_no,
            trade_no = out_trade_no,
            amount = money,
        }), json.encode(params), json.encode(options))

        return json.encode({
            error_code = err_code,
            error_message = err_message,
            response = response,
        })
    else
        return json.encode({
            error_code = 500,
            error_message = "签名校验失败"
        })

    end
end


-- 签名
function plugin._getSign(param, key)
    local signstr = ''
    local keys = {}

    for k, _ in pairs(param) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = param[k]
        if k ~= "sign" and k ~= "sign_type" and v ~= '' then
            signstr = signstr .. k .. '=' .. v .. '&'
        end
    end

    signstr = string.sub(signstr, 1, -2)
    signstr = signstr .. key
    local sign = helper.md5(signstr)
    return sign
end
