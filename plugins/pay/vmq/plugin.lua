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
        name = 'vmq',
        title = 'V免签',
        author = '官方',
        description = "V免签 支付通道",
        link = 'https://github.com/szvone/vmqphp',
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = 'V免签',
                    value = 'alipay_vmq'
                },
            },
            wxpay = {
                {
                    label = 'V免签',
                    value = 'wxpay_vmq'
                },
            },
            qqpay = {
                {
                    label = 'V免签',
                    value = 'qqpay_vmq'
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
                name = 'host',
                label = '通讯地址',
                type = 'input',
                default = "",
                placeholder = "请输入通讯地址",
                options = {
                    tip = '如: https://xxx.com/',
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
                name = 'pid',
                label = '商户ID',
                type = 'input',
                default = "",
                placeholder = "请输入商户ID",
                options = {
                    tip = "如果不需要商户ID，随便填写即可",
                },

            },
            {
                name = 'key',
                label = '通讯密钥',
                type = 'password',
                default = "",
                placeholder = "请输入通讯密钥",
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
                name = 'method',
                label = '请求方式',
                type = 'select',
                default = "POST",
                options = {
                    tip = '',
                },
                placeholder = "请选择请求方式",
                values = {
                    {
                        label = "GET",
                        value = "GET"
                    },
                    {
                        label = "POST",
                        value = "POST"
                    },
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

    local host = options['host'] .. "createOrder"
    local pid = options['pid']
    local key = options['key']
    local method = options['method']

    local payType = ""
    if orderInfo['pay_type'] == "alipay" then
        payType = "2"
    elseif orderInfo['pay_type'] == "qqpay" then
        payType = "4"
    elseif orderInfo['pay_type'] == "wxpay" then
        payType = "1"
    elseif orderInfo['pay_type'] == "bank" then
        payType = "3"

    end

    -- 组装提交请求
    local req = {
        mchId = pid,
        payId = orderInfo['order_id'],
        type = payType,
        price = orderInfo['trade_amount_str'],
        isHtml = "1",
        notifyUrl = orderInfo['notify_url'],
        returnUrl = orderInfo['return_url'],
    }
    req.sign = helper.md5(req.payId .. req.type .. req.price .. key)


    -- 处理发送内容
    if method == "POST" then
        local content = plugin._pagePay(req, host, "正在跳转中,未跳转点击我")
        return json.encode({
            type = "html",
            qrcode = "",
            url = "",
            content = content,
            err_code = 200,
            err_message = ""
        })
    else
        return json.encode({
            type = "jump",
            qrcode = '',
            url = host .. "?" .. funcs.table_http_query(req),
            content = "",
            out_trade_no = "",
            err_code = 200,
            err_message = ""
        })

    end

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
    local sign = plugin._getSign(reqData, options['key'])
    if sign == reqData['sign'] then
        -- 商户订单号
        local out_trade_no = reqData['payId']

        -- 避免精度有问题
        local price = math.floor((reqData['price'] + 0.000005) * 100)
        local reallyPrice = math.floor((reqData['reallyPrice'] + 0.000005) * 100)

        if price == reallyPrice then
            -- 通知订单处理完成
            local err_code, err_message, response = orderHelper.notify_process(json.encode({
                out_trade_no = "",
                trade_no = out_trade_no,
                amount = price,
            }), json.encode(params), json.encode(options))

            return json.encode({
                error_code = err_code,
                error_message = err_message,
                response = response,
            })
        end


        return json.encode({
            error_code = 500,
            error_message = "订单支付异常"
        })

    else
        return json.encode({
            error_code = 500,
            error_message = "签名校验失败"
        })

    end
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
    local payId = param['payId']; -- 商户订单号
    local type = param['type'];-- 支付方式 ：微信支付为1 支付宝支付为2 中国银联（云闪付）传入3 QQ钱包传入4
    local price = param['price'];-- 订单金额
    local reallyPrice = param['reallyPrice'];-- 实际支付金额
    return helper.md5(payId .. type .. price .. reallyPrice .. key)
end
