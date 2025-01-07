-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local orderPayHelper = require("orderPayHelper")

PAY_BANK_JDSYT = "bank_jdsyt"

--- 插件信息
plugin = {
    info = {
        name = 'jdsyt',
        title = '京东收银台',
        author = '包子',
        description = "京东收银台",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            bank = {
                {
                    label = '京东收银台',
                    value = PAY_BANK_JDSYT,
                    -- 绑定支付方式
                    bind_pay_type = { "alipay", "wxpay", "bank" },
                },
            },
        },
        options = {
            -- 检查间隔定时任务 待定
            --detection_cron = "*/3 * * * *",
            -- 检查任务时间 二选一 此优先
            detection_interval = 3,
            -- 检查任务类型
            detection_type = "order", --- order 单订单检查 cron 定时执行任务
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
                name = 'number',
                label = '设备ID',
                type = 'input',
                default = "",
                placeholder = "请填写京东收银台设备ID",
                options = {
                    append_deqrocde = 1, -- 增加解析二维码功能
                    tip = '',
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

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }
    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    return json.encode({
        type = "qrcode",
        qrcode = plugin.getQrcode(orderInfo, options),
        url = "",
        content = "",
        out_trade_no = '',
        err_code = 200,
        err_message = ""
    })

end

-- 获取支付码
function plugin.getQrcode(orderInfo, pluginOptions)
    return string.format("https://order.duolabao.com/active/c?state=%s%%7C%s%%7C%.2f%%7C%%7CAPI", orderInfo["order_id"], pluginOptions['number'], orderInfo['trade_amount'] / 100)
end

-- 定期执行
function plugin.cron()

end

-- 检查单个订单
function plugin.checkOrder(orderInfoJson, pluginOptions)
    local orderInfo = json.decode(orderInfoJson)
    if orderInfo["out_pay_data"] then
        local err_code,err_message = orderPayHelper.jdsyt_check(orderInfoJson,pluginOptions)
        return json.encode({
            error_code = err_code,
            error_message = err_message,
        })
    end
    return json.encode({
        error_code = 500,
        error_message = "暂不支持",
    })

end