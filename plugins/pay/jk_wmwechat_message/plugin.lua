local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")


-- 追加
PAY_WXPAY_XINSHENGYI = "jk_wxpay_xinshengyi"
PAY_WXPAY_PCLAKALA = "jk_wxpay_pclakala"
PAY_ALIPAY_PCLAKALA = "jk_alipay_pclakala"
PAY_ALIPAY_XINSHENGYI = "jk_alipay_xinshengyi"


--- 插件信息
plugin = {
    info = {
        name = 'jk_wmwechat_message',
        title = '监控插件 - 微信公众号/小程序',
        author = '闲蛋',
        description = "微信公众号模板消息/小程序消息 闲蛋插件",
        link = 'https://www.xdau.cn/',
        version = "1.4.4",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '支付宝拉卡拉-XD监控端',
                    value = PAY_ALIPAY_PCLAKALA,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '支付宝新生易-XD监控端',
                    value = PAY_ALIPAY_XINSHENGYI,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
            },
            wxpay = {
                {
                    label = '微信新生易-XD监控端',
                    value = PAY_WXPAY_XINSHENGYI,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '微信拉卡拉-XD监控端',
                    value = PAY_WXPAY_PCLAKALA,
                    -- 支持上报
                    report = 1,
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
                placeholder = "请输入收款码地址",
                when = "this.formModel.options.type == 'url'",
                options = {
                    append_deqrocde = 1, -- 增加解析二维码功能
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
                        message = "请输入"
                    }
                }
            },
            {
                name = 'type',
                label = '收款码类型',
                type = 'select',
                default = "url",
                options = {
                    tip = '',
                },
                placeholder = "请选择收款码类型",
                values = {
                    {
                        label = "地址",
                        value = "url"
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
function plugin.parseMsg(msg)
    return json.encode({
        error_code = 500,
        error_message = "暂不支持",
        response = "",
    })
end