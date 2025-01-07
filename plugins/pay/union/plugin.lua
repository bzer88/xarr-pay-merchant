-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local xml = require("xml")
local helper = require("helper")
local orderHelper = require("orderHelper")

PAY_BANK_UNION = "bank_union"

--- 插件信息
plugin = {
    info = {
        name = PAY_BANK_UNION,
        title = '银联前置',
        author = '官方',
        description = "银联前置",
        link = 'https://www.xarr.cn',
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            bank = {
                {
                    label = '银联前置',
                    value = PAY_BANK_UNION,
                    bind_pay_type = { "alipay", "wxpay", "bank" },
                },
            },
        },
        options = {
            callback = 1,
            detection_interval = 0,
        },

    },
    gateway = "https://qra.95516.com/pay/gateway"
}

function plugin.pluginInfo()
    return json.encode(plugin.info)
end

-- 获取form表单
function plugin.formItems(payType, payChannel)
    return json.encode({
        inputs = {
            {
                name = 'mch_id',
                label = '商户号',
                type = 'input',
                default = "",
                placeholder = "请输入商户号",
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
                name = 'key',
                label = '商户密钥',
                type = 'input',
                default = "",
                placeholder = "请输入商户密钥",
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

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }
    local orderInfoDe = json.decode(orderInfo)
    local pluginOptionsDe = json.decode(pluginOptions)
    print(pluginOptions,"账户参数")

    local requestData = {
        service = "unified.trade.native",
        --version = "",
        --sign_type = "",
        mch_id = pluginOptionsDe.mch_id,
        out_trade_no = orderInfoDe.order_id,
        body = orderInfoDe.subject,
        --attach = "",
        total_fee = orderInfoDe.trade_amount,
        mch_create_ip = "127.0.0.1",
        notify_url = orderInfoDe.notify_url,
        time_start = helper.time_now_small_time(),
        time_expire = helper.time_now_small_time(5 * 60),
        nonce_str = helper.str_random(20),
        --sign = "",
    }
    local sign = plugin._getSign(requestData, "&key=" .. pluginOptionsDe.key)
    requestData.sign = string.upper(sign)
    local params = {
        query = "",
        body = funcs.table_to_xml_string("1.0","utf-8",requestData),
        form = "",
        timeout = "30s",
        headers = {
            ["content-type"] = "application/xml"
        }
    }
    local response, error_message = http.request("POST", plugin.gateway, params)

    if response and response.body then
        local res = response.body
        print("返回数据",res)
        -- 解析xml
        local xmlParser = xml.newParser()
        local parsedXml = xmlParser:ParseXmlText(res)

        local code = parsedXml.xml.code_url:value()
        code = code:gsub("<!%[CDATA%[(.*)%]%]>","%1")
        local status = parsedXml.xml.status:value()
        status = status:gsub("<!%[CDATA%[(.*)%]%]>","%1")

        if status == '0' then
            if code ~= "" then
                return json.encode({
                    type = "qrcode",
                    qrcode = code,
                    url = "",
                    content = "",
                    out_trade_no = '',
                    err_code = 200,
                    err_message = ""
                })
            end
        end
    end

    return json.encode({
        type = 'error',
        err_code = 500,
        err_message = '开发中'
    })

end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    request = json.decode(request)
    params = json.decode(params)
    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    -- 转为json处理
    local reqDataJson = helper.xml_to_json(request['body_string'])
    if reqDataJson == "" then
        return json.encode({
            error_code = 500,
            error_message = "回调数据异常"
        })
    end

    local reqData = json.decode(reqDataJson)


    -- 获取签名内容
    local sign = plugin._getSign(reqData,"&key=".. options['key']):upper()
    if sign == reqData['sign']:upper() then
        -- 签名校验成功
        if reqData['status'] ~= "0" then
            return json.encode({
                error_code = 500,
                error_message = "支付订单未完成"
            })
        end
        if reqData['pay_result'] ~= "0" then
            return json.encode({
                error_code = 500,
                error_message = "支付订单未完成2"
            })
        end

        -- 商户订单号
        local out_trade_no = reqData['out_trade_no']
        -- 外部系统订单号
        local trade_no = reqData['transaction_id']
        -- 避免精度有问题
        local money = math.floor((reqData['total_fee'] + 0.000005) * 1)

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
        if k ~= "sign" and v ~= '' then
            signstr = signstr .. k .. '=' .. v .. '&'
        end
    end

    signstr = string.sub(signstr, 1, -2)
    signstr = signstr .. key
    local sign = helper.md5(signstr)
    return sign
end
