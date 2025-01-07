-- 载入插件
local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local orderPayHelper = require("orderPayHelper")

PAY_WXPAY_NATIVE_V3 = "wxpay_native_v3"

--- 插件信息
plugin = {
    info = {
        name = PAY_WXPAY_NATIVE_V3,
        title = '微信-NativeV3',
        author = '官方',
        link = 'https://www.xarr.cn',
        description = "微信官方支付-NativeV3",
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = '微信-NativeV3',
                    value = PAY_WXPAY_NATIVE_V3
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
                name = 'appid',
                label = '应用ID',
                type = 'input',
                default = "",
                placeholder = "应用ID",
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
                name = 'mchid',
                label = '商户ID',
                type = 'input',
                default = "",
                placeholder = "商户ID 或者服务商模式的 sp_mchid",
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
                name = 'serial_no',
                label = '证书序列号',
                type = 'input',
                hidden_list = 1,
                default = "",
                placeholder = "商户API证书的证书序列号",
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
                name = 'api_v3_key',
                label = '商户APIV3Key',
                type = 'input',
                default = "",
                hidden_list = 1,
                placeholder = "商户平台获取",
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
                name = 'private_key',
                label = '商户API证书私钥',
                type = 'textarea',
                default = "",
                hidden_list = 1,
                placeholder = "商户API证书下载后，私钥 apiclient_key.pem 读取后的字符串内容",
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
                name = 'public_key',
                label = '证书公钥',
                type = 'textarea',
                default = "",
                hidden_list = 1,
                placeholder = "商户API证书下载后，私钥 apiclient_key.pem 读取后的字符串内容",
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

    local err_code, err_message, result = orderPayHelper.wxpay_native_v3_create(orderInfo, pluginOptions)

    if err_code ~= 200 then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = err_message
        })
    elseif err_code == 200 then
        return json.encode({
            type = "qrcode",
            qrcode = result,
            url = "",
            content = "",
            out_trade_no = "",
            err_code = 200,
            err_message = ""
        })
    end

    return json.encode({
        type = 'error',
        err_code = 500,
        err_message = '创建支付失败'
    })
end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    local err_code, err_message, response = orderPayHelper.wxpay_native_v3_notify(request, orderInfo, pluginOptions)

    return json.encode({
        error_code = err_code,
        error_message = err_message,
        response = response,
    })

end
