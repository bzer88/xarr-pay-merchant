-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")

-- 定义常量
PAY_JK_LAKALAAlipay = "jk_lakala_alipay"
PAY_JK_LAKALAWechat = "jk_lakala_wechat"
PAY_JK_LAKALABank = "jk_lakala_bank"

--- 插件信息
plugin = {
    info = {
        name = "jk_lakala",
        title = '监控插件 - 拉卡拉',
        author = '包子',
        description = "监控插件",
        link = 'https://blog.52nyg.com',
        version = "1.0.0",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '拉卡拉-监控端',
                    value = PAY_JK_LAKALAAlipay,
                    -- 支持上报
                    report = 1,
                    -- 无上报SMS信息
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
            },
            wxpay = {
                {
                    label = '拉卡拉-监控端',
                    value = PAY_JK_LAKALAWechat,
                    -- 支持上报
                    report = 1,
                    -- 无上报SMS信息
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },

            },
            bank = {
                {
                    label = '拉卡拉-监控端',
                    value = PAY_JK_LAKALABank,
                    -- 支持上报
                    report = 1,
                    -- 无上报SMS信息
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },

            },
        },
        options = {
            _ = ""
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
                        label = "图片",
                        value = "image"
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
        },
    })

end

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }

    orderInfo = json.decode(orderInfo)
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

    end

    return json.encode({
        type = "qrcode",
        qrcode = options['qrcode'],
        url = "",
        content = "",
        out_trade_no = '',
        err_code = 200,
        err_message = ""
    })

end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    -- 判断请求方式
    return json.encode({
        error_code = 500,
        error_message = "暂不支持",
        response = "",
    })

end



-- 解析上报数据
function plugin.parseMsg(pMsg)
    local msg = json.decode(pMsg)
    local reportApps = {
        ["com.lakala.shqb"] = {
            {
                TitleReg = "拉卡拉",
                ContentReg = "微信成功收款(?<amount>[\\d\\.]+)元。",
                Code = PAY_JK_LAKALAWechat
            },
            {
                TitleReg = "拉卡拉",
                ContentReg = "支付宝成功收款(?<amount>[\\d\\.]+)元。",
                Code = PAY_JK_LAKALAAlipay
            },
            {
                TitleReg = "拉卡拉",
                ContentReg = "银联二维码成功收款(?<amount>[\\d\\.]+)元。",
                Code = PAY_JK_LAKALABank
            },
        }
    }

    -- 获取包名
    local packageName = msg.package_name

    if reportApps[packageName] then
        -- 循环规则
        for i, v in ipairs(reportApps[packageName]) do
            -- 判断渠道是否一样的
            if v.Code == msg['channel_code'] then
                -- 匹配标题
                local titleMatched = helper.regexp_match(msg.title, v.TitleReg)
                if titleMatched then
                    -- 调用正则
                    local matched, matchGroups = helper.regexp_match_group(msg.content, v.ContentReg)

                    -- 判断匹配是否成功
                    if matched == true then

                        -- 解析正则中的价格
                        matchGroups = json.decode(matchGroups)

                        -- 判断是否解析成功
                        if matchGroups['amount'] and #matchGroups['amount'] > 0 then
                            -- 匹配到金额
                            return json.encode({
                                err_code = 200,
                                amount = matchGroups['amount'][1],
                            })
                        end
                    end

                end
            end


        end


    end
    -- 匹配到金额
    return json.encode({
        err_code = 500,
        err_message = "未能匹配"
    })

end