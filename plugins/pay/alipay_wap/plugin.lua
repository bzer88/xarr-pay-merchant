-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local helper = require("helper")
local json = require("json")
local orderPayHelper = require("orderPayHelper")

PAY_ALIPAY_WAP = "alipay_wap"

--- 插件信息
plugin = {
    info = {
        name = PAY_ALIPAY_WAP,
        title = '支付宝-手机网站支付',
        author = '官方',
        description = "支付宝官方手机网站支付",
        link = 'https://b.alipay.com/',
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '手机网站支付',
                    value = PAY_ALIPAY_WAP
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
                hidden_list = 1,
                default = "",
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
                name = 'alipay_public',
                label = '支付宝公钥',
                type = 'textarea',
                hidden_list = 1,
                default = "",
                placeholder = "请输入支付宝公钥",
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

function plugin.create(pOrderInfo, pluginOptions, pAccountInfo, pDeviceInfo)
    local vDeviceInfo = json.decode(pDeviceInfo)

    local err_code, err_message, result = orderPayHelper.alipay_wap_create(pOrderInfo, pluginOptions)

    if err_code ~= 200 then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = err_message
        })
    elseif err_code == 200 then
        if vDeviceInfo.is_mobile then
            return json.encode({
                type = "jump",
                url = result,
                err_code = 200,
                err_message = ""
            })
        else
            return json.encode({
                type = "qrcode",
                qrcode = result,
                url = "",
                qrcode_use_short_url = 1,
                content = "",
                out_trade_no = "",
                scheme = "alipayqr://platformapi/startapp?saId=20000032&url=" .. helper.url_encode(result),
                err_code = 200,
                err_message = ""
            })
        end

    end

    return json.encode({
        type = 'error',
        err_code = 500,
        err_message = '创建支付失败'
    })
end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    local err_code, err_message, response = orderPayHelper.alipay_wap_notify(request, orderInfo, pluginOptions)

    return json.encode({
        error_code = err_code,
        error_message = err_message,
        response = response,
    })

end
