local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")
local orderPayHelper = require("orderPayHelper")

PAY_BANK_HUIFU = "huifu"

--- 插件信息
plugin = {
    info = {
        name = PAY_BANK_HUIFU,
        title = '汇付天下',
        author = '官方',
        description = "汇付斗拱平台",
        link = 'https://paas.huifu.com/',
        version = "1.4.4",
        -- 支持支付类型
        channels = {
            bank = {
                {
                    label = '汇付斗拱平台',
                    value = PAY_BANK_HUIFU,
                    -- 绑定支付方式
                    bind_pay_type = { "alipay", "wxpay", "bank" },
                },
            },

        },
        options = {
            callback = 1,
            detection_interval = 0,
        },
        gateway = "https://api.huifu.com"
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
                name = 'sys_id',
                label = '汇付系统号',
                type = 'input',
                default = "",
                placeholder = "请输入汇付系统号",
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
                name = 'product_id',
                label = '汇付产品号',
                type = 'input',
                default = "",
                placeholder = "请输入汇付产品号",
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
                name = 'huifu_id',
                label = '汇付子商户号',
                type = 'input',
                default = "",
                placeholder = "请输入汇付子商户号",
                options = {
                    tip = '当主体为渠道商时需要填写，主体为直连商户时不需要填写',
                },

            },
            {
                name = 'project_id',
                label = '半支付托管项目号',
                type = 'input',
                default = "",
                placeholder = "请输入半支付托管项目号",
                options = {
                    tip = '仅托管支付需要填写',
                },

            },
            {
                name = 'merchant_private_key',
                label = '商户私钥',
                type = 'textarea',
                hidden_list = 1,
                default = "",
                placeholder = "请输入商户私钥",
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
                name = 'huifu_public_key',
                label = '汇付公钥',
                type = 'textarea',
                hidden_list = 1,
                default = "",
                placeholder = "请输入汇付公钥",
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

function plugin.create(pOrderInfo, pPluginOptions, ...)
    local args = { ... }

    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pPluginOptions)

    local huifuId = options.sys_id
    if options.huifu_id ~= "" then
        huifuId = options.huifu_id
    end

    --T_JSAPI: 微信公众号
    --T_MINIAPP: 微信小程序
    --A_JSAPI: 支付宝JS
    --A_NATIVE: 支付宝正扫
    --U_NATIVE: 银联正扫
    --U_JSAPI: 银联JS
    --D_NATIVE: 数字人民币正扫
    --T_H5：微信直连H5支付
    --T_APP：微信APP支付
    --T_NATIVE：微信正扫

    local tradeType = ""
    if orderInfo.pay_type == "alipay" then
        tradeType = "A_NATIVE"
    elseif orderInfo.pay_type == "wxpay" then
        tradeType = "T_NATIVE"
    elseif orderInfo.pay_type == "bank" then
        tradeType = "U_NATIVE"
    end

    local param = {
        req_date = helper.time_now_ymd_time(),
        req_seq_id = orderInfo.order_id,
        huifu_id = huifuId,
        trade_type = tradeType,
        trans_amt = orderInfo.trade_amount_str,
        goods_desc = orderInfo.subject,
        notify_url = orderInfo.notify_url,
        risk_check_data = json.encode({ ip_addr = orderInfo.client_ip }),
    };
    if tradeType == "T_NATIVE" then
        param['wx_data'] = json.encode({
            product_id = "01001"
        })
    end

    local uri = plugin.info.gateway .. "/v2/trade/payment/jspay"



    local body = {
        sys_id = options.sys_id,
        product_id = options.product_id,
        data = param,
        sign = ""
    }
    body.sign = plugin.makeSign(param, options.merchant_private_key)
    local params = {
        query = "",
        body = json.encode(body),
        form = "",
        timeout = "30s",
        headers = {
            ["content-type"] = "application/json; charset=utf-8"
        }
    }


    local response, error_message = http.request("POST", uri, params)

    if response.status_code ~= 200 then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = '请求响应错误 返回内容:' .. response.body
        })
    end


    -- 解析内容
    local result = json.decode(response.body)
    if result.data == nil or result.data.resp_code == nil then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = "汇付返回结构错误"
        })
    end

    result = result.data


    local err_code = result.resp_code
    if err_code == nil then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = '请求响应错误 返回内容:' .. response.body
        })
    end
    local err_message = result.resp_desc
    local bank_message = result.bank_message
    if bank_message ~= nil then
        err_message = err_message .. " " .. bank_message
    end

    if err_code ~= "00000100" then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = err_message
        })
    end

    return json.encode({
        type = "qrcode",
        qrcode = result.qr_code,
        url = "",
        qrcode_use_short_url = 0,
        content = "",
        out_trade_no = "",
        err_code = 200,
        err_message = ""
    })


end

-- 支付回调
function plugin.notify(pRequest, pOrderInfo, pParams, pPluginOptions)
    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pPluginOptions)
    local request = json.decode(pRequest)
    local params = json.decode(pParams)
    local reqData = request['body']

    local reqDataObj = json.decode(reqData['resp_data'])
    if reqDataObj == nil then
        return json.encode({
            error_code = 500,
            error_message = "异步回调数据错误"
        })
    end

    -- 判断签名
    local reqSign = reqData['sign']
    local sign = plugin.checkNotifySign(reqData['resp_data'],reqSign, options.huifu_public_key)
    if sign == false then
        return json.encode({
            error_code = 500,
            error_message = "签名错误"
        })
    end

    -- 判断订单状态
    if reqDataObj["trans_stat"] == "S" then
        if reqDataObj["req_seq_id"] == orderInfo.order_id then
            -- 商户订单号
            local out_trade_no = reqDataObj['req_seq_id']
            -- 外部系统订单号
            local trade_no = reqDataObj['hf_seq_id']
            -- 避免精度有问题
            local money = math.floor((reqDataObj['trans_amt'] + 0.000005) * 100)

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
                error_message = "订单号不匹配"
            })
        end
    end

    return json.encode({
        error_code = 500,
        error_message = "订单状态错误"
    })



end

function plugin.makeSign(params, private_key)
    -- 创建一个新的表来存储非空值
    local filtered_params = {}

    -- 过滤参数
    for key, value in pairs(params) do
        if value ~= nil then
            filtered_params[key] = value
        end
    end

    -- 对表进行排序
    local sorted_params = {}
    for key in pairs(filtered_params) do
        table.insert(sorted_params, key)
    end
    table.sort(sorted_params)
    --content = "{" .. table.concat(content, ",") .. "}"

    -- 根据顺序添加到对象中
    local data = {}
    for _, key in ipairs(sorted_params) do
        data[key] = filtered_params[key]
    end

    local content = json.encode(data)

    return helper.rsa_private_sign_base64(content, private_key, "SHA256")
end


function plugin.checkNotifySign(content, sign, public_key)
    return helper.rsa_public_verify_sign_base64(content, sign,public_key, "SHA256")
end