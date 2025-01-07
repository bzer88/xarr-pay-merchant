-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local orderHelper = require("orderHelper")
local helper = require("helper")

--- 插件信息
plugin = {
    info = {
        name = 'xunhupay-hupijiao',
        title = '讯虎-虎皮椒',
        author = '官方',
        description = "讯虎-虎皮椒(未测试)",
        link = 'https://www.xunhupay.com/',
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            bank = {
                {
                    label = '虎皮椒',
                    value = 'bank_xunhu_hupijiao',
                    bind_pay_type = { "alipay", "wxpay", "bank" },
                },
            },
        },
        options = {
            -- 支持回调
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
                label = '网关',
                type = 'input',
                default = "https://api.xunhupay.com/",
                placeholder = "请输入网关地址",
                options = {
                    tip = '如: https://api.xunhupay.com/',
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
                name = 'app_id',
                label = 'AppID',
                type = 'input',
                default = "",
                placeholder = "请输入AppID",
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
                name = 'secret',
                label = '密钥',
                type = 'password',
                default = "",
                placeholder = "请输入密钥",
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

    local gateway = options['gateway']
    local appId = options['app_id']
    local appSecret = options['secret']


    -- 组装提交请求
    local req = {
        version = "1.1",
        trade_order_id = orderInfo['order_id'],
        total_fee = orderInfo['trade_amount'] / 100,
        title = orderInfo['subject'],
        appid = appId,
        notify_url = orderInfo['notify_url'],
        return_url = orderInfo['return_url'],
        nonce_str = helper.str_random(20),
        wap_name = orderInfo['merchant_name'],
        type = ""
    }
    if orderInfo.pay_type == "alipay" then
        req.type = ""
    elseif orderInfo.pay_type == "wxpay" then
        req.type = "WAP"
    end

    req.hash = plugin._getSign(req, appSecret)


    local sendData = {}
    local res = ""
    local err = nil
    local error_message = nil
    local response = {}

    -- 创建订单接口导致
    local uri = gateway .. "payment/do.html"


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


    print("[插件] 请求地址" .. uri)
    print("[插件] 请求内容" .. funcs.table_http_query(req))
    print("[插件] 返回内容" .. res)
    local returnInfo = json.decode(res)

    if returnInfo == nil then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = '请求响应错误 返回内容:' .. res
        })
    end

    if returnInfo['errcode'] ~= 0 or returnInfo['errmsg'] ~= "success!"  then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = returnInfo['errmsg'] or returnInfo['errmsg']
        })
    end

    if returnInfo['url'] then
        return json.encode({
            type = "jump",
            qrcode = '',
            url = returnInfo["url"],
            content = "",
            out_trade_no = returnInfo['oderid'],
            err_code = 200,
            err_message = ""
        })
    end

    return json.encode({
        type = "qrcode",
        qrcode = returnInfo['url_qrcode'],
        url = returnInfo["url"],
        content = "",
        out_trade_no = returnInfo['oderid'],
        err_code = 200,
        err_message = ""
    })


end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    request = json.decode(request)
    params = json.decode(params)
    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    -- 判断请求方式
    local reqData = ""
    if request['method'] == 'POST' then
        reqData = (request['body'])
    else
        reqData = (request['query'])
    end

    -- 获取签名内容
    local sign = plugin._getSign(reqData, options['secret'])
    if sign == reqData['hash'] then
        -- 签名校验成功
        if reqData['appid'] ~= options['app_id'] then
            return json.encode({
                error_code = 500,
                error_message = "交易商户号异常"
            })
        end
        -- 商户订单号
        local out_trade_no = reqData['trade_order_id']
        -- 外部系统订单号
        local trade_no = reqData['transaction_id']
        -- 避免精度有问题
        local money = math.floor((reqData['total_fee'] + 0.000005) * 100)

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

-- 绑定参数
function plugin._buildRequestParams(params, key)
    params['sign'] = plugin._getSign(params, key)
    params['sign_type'] = 'MD5'
    return params
end


-- 发起支付（页面跳转）
function plugin._pagePay(param, submit_url, button)
    local html = '<form id="dopay" action="' .. submit_url .. '" method="post">'

    for k, v in pairs(param) do
        html = html .. '<input type="hidden" name="' .. k .. '" value="' .. v .. '"/>'
    end

    html = html .. '<input type="submit" value="' .. button .. '"></form><script>document.getElementById("dopay").submit();</script>'

    return html
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
