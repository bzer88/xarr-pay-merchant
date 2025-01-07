-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local orderPayHelper = require("orderPayHelper")

PAY_ALIPAY_PRE_PAY = "alipay_prepay"

--- 插件信息
plugin = {
    info = {
        name = PAY_ALIPAY_PRE_PAY,
        title = '支付宝-预授权支付',
        author = '官方',
        description = "支付宝官方预授权支付",
        link = 'https://b.alipay.com',
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '预授权支付',
                    value = PAY_ALIPAY_PRE_PAY
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
                placeholder = "请输入应用私钥",
                hidden_list = 1,
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
                name = 'alipay_public',
                label = '支付宝公钥',
                type = 'textarea',
                default = "",
                placeholder = "请输入支付宝公钥",
                hidden_list = 1,
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
                name = 'type',
                label = '用户类型',
                type = 'select',
                default = "1",
                placeholder = "请选择",
                values = {
                    {
                        label = "商户",
                        value = "1",
                    },
                    {
                        label = "服务商",
                        value = "2",
                    },
                },
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
                name = 'token',
                label = '用户Token',
                type = 'input',
                default = "",
                when = "this.formModel.options.type == '2'",
                placeholder = "请输入用户Token",
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

    local err_code, err_message, result = orderPayHelper.alipay_prepay_create(orderInfo, pluginOptions)

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
    local err_code, err_message, response = orderPayHelper.alipay_prepay_notify(request, orderInfo, pluginOptions)

    return json.encode({
        error_code = err_code,
        error_message = err_message,
        response = response,
    })

end
