-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")
local orderPayHelper = require("orderPayHelper")

PAY_CHANNEL_CODE_YUN_WECHAT_UOS = "yun_wechat_uos"
--- 插件信息
plugin = {
    info = {
        name = PAY_CHANNEL_CODE_YUN_WECHAT_UOS,
        title = '微信-UOS',
        author = '第三方',
        description = "微信-UOS 仅供学习写法,切勿使用",
        link = 'https://blog.52nyg.com/',
        version = "1.4.5",
        -- 最小支持主程序版本号
        min_main_version = "1.3.8",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = '微信-UOS',
                    value = PAY_CHANNEL_CODE_YUN_WECHAT_UOS,
                    options = {
                        -- 使用递增金额
                        use_add_amount = 1,
                        -- 使用二维码登录流程
                        use_qrcode_login = 1
                    }
                },
            },
        },
        options = {
            -- 启动定时查询在线状态
            detection_interval = 6,
            detection_type = "cron", --- order 单订单检查 cron 定时执行任务
            -- 配置项
            --options = {
            --    {
            --        title = "云端地址", placeholder = "多个以英文逗号[,]分割", key = "host", default = "https://api.xxx.com"
            --    },
            --}
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
                label = '选择网关',
                type = 'select',
                default = "",
                options = {
                    tip = '',
                },
                placeholder = "请选址网关",
                options = {
                    -- 选择网关
                    chose_gateway = 1,
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请选择",
                    }
                }
            },
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
            {
                name = 'bind_token',
                label = '绑定的用户信息',
                type = "input",
                hidden = 1,
            },
            {
                name = 'client_id',
                label = '客户端ID',
                type = "input",
                options = {
                    tip = '清空将使用新的客户端ID',
                },
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
        qrcode = " "..options['qrcode'].." '",
        url = "",
        content = "",
        out_trade_no = '',
        err_code = 200,
        err_message = ""
    })
end

-- 定时任务
function plugin.cron(pAccountInfo, pPluginOptions)
    local vAccountInfo = json.decode(pAccountInfo)
    local vParams = json.decode(vAccountInfo.options)

    if vAccountInfo.online ~= 1 then
        return json.encode({
            err_code = 500,
            err_message= "账号已离线"
        })
    end

    
    if vParams.bind_token == "" then
        if vAccountInfo.online == 1 then
            -- 设置离线
            helper.channel_account_offline(vAccountInfo.id)
        end

        return json.encode({
            err_code = 500,
            err_message = "未登录"
        })
    end

    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vParams.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end

    local bindTokeInfo = json.decode(vParams.bind_token)

    local apiUri = string.format('%s/api/client/sync-msg', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("client_id=%s", bindTokeInfo.client_id),
        timeout = "30s",

    })
    if response.status_code ~= 200 then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', response.status_code)
        })
    end

    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end

    if returnInfo.code ~= 200 then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = returnInfo.message
        })
    end

    -- 如果离线状态 则设置为在线
    if vAccountInfo.online ~= 1 then
        -- 设置在线
        helper.channel_account_online(vAccountInfo.id)
    end


    -- 解析消息
    if returnInfo.data.AddMsgCount > 0 then
        for i, v in ipairs(returnInfo.data.AddMsgList) do
            if v.AppMsgType ~= 0 then
                print("消息来了", json.encode(returnInfo))
                -- 推送外部订单
                plugin.parseMsg(vAccountInfo, v)

            end
        end
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('在线')
    })

end

function plugin.parseMsg(vAccountInfo, msg)
    local rules = {
        {
            TitleReg = "微信收款助手",
            ContentReg = "^(?:\\[\\d+条\\]微信收款助手: )?微信支付收款(?<amount>[\\d\\.]+)元(\\(([新老]顾客)?(朋友)?到店\\))?",
        },
        {
            TitleReg = "微信支付",
            ContentReg = "微信支付：微信支付收款(?<amount>[\\d\\.]+)元",
        },
        {
            TitleReg = "微信支付",
            ContentReg = "个人收款码到账¥(?<amount>[\\d\\.]+)",
        },
        {
            TitleReg = "微信收款助手",
            ContentReg = "\\[店员消息\\]收款到账(?<amount>[\\d\\.]+)元",
        },
        {
            TitleReg = "微信支付",
            ContentReg = "二维码赞赏到账(?<amount>[\\d\\.]+)元",
        },

        -- 经营码
        {
            TitleReg = "微信收款商业版",
            ContentReg = "收款(?<amount>[\\d\\.]+)元",
        },
        {
            TitleReg = "收款通知",
            ContentReg = "微信收款商业版: 收款(?<amount>[\\d\\.]+)元",
        },
        {
            TitleReg = "微信收款助手",
            ContentReg = "收款单到账(?<amount>[\\d\\.]+)元",
        },
    }
    -- 循环规则
    for i, v in ipairs(rules) do
        -- 判断渠道是否一样的
        -- 匹配标题
        local titleMatched = helper.regexp_match(msg.AppName, v.TitleReg)
        if titleMatched then
            -- 调用正则
            local matched, matchGroups = helper.regexp_match_group(msg.Title, v.ContentReg)

            -- 判断匹配是否成功
            if matched == true then
                -- 解析正则中的价格
                matchGroups = json.decode(matchGroups)
                -- 判断是否解析成功
                if matchGroups['amount'] and #matchGroups['amount'] > 0 then
                    -- 避免精度有问题
                    local price = math.floor((matchGroups['amount'][1] + 0.000005) * 100)
                    orderHelper.report(vAccountInfo, {
                        amount = price,
                        pay_type = "wxpay",
                        channel_code = PAY_CHANNEL_CODE_YUN_WECHAT_UOS,
                        pay_time = msg.CreateTime,
                    })

                end
            end

        end


    end


end


-- 二维码登录
function plugin.login_qrcode(pAccountInfo, pUserInfo, pParams)
    local vParams = json.decode(pParams)
    local vAccountInfo = json.decode(pAccountInfo)
    local vAccountOption = json.decode(vAccountInfo.options)
    local vUserInfo = json.decode(pUserInfo)

    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vAccountOption.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end
    local client_id =vAccountOption.client_id
    if vAccountOption.client_id == nil or   vAccountOption.client_id == "" then
        -- 1. 创建客户端
        local apiUri = string.format('%s/api/client/create', serverAddress)

        local response, error_message = http.request("POST", apiUri, {
            timeout = "30s",

        })
        if error_message ~= nil then
            return json.encode({
                err_code = 500,
                err_message = string.format('请求错误: %v', error_message)
            })
        end

        local returnInfo = json.decode(response.body)
        print("创建客户端返回内容", response.body)
        if returnInfo.code == nil then
            return json.encode({
                err_code = 500,
                err_message = string.format('请求响应错误,响应内容: %v', response.body)
            })
        end
        if returnInfo.code ~= 200 then
            return json.encode({
                err_code = 500,
                err_message = string.format('返回错误状态码 响应内容: %v', response.body)
            })
        end
        client_id = returnInfo.data.client_id

    end




    -- 2. 获取登录二维码
    local apiUri = string.format('%s/api/login/qrcode', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("client_id=%s", client_id),
        timeout = "30s",
    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求获取登录二维码错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    print("创建二维码返回内容", response.body)
    if returnInfo.code ~= 200 then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    return json.encode({
        -- 返回二维码
        qrcode = returnInfo.data.qrcode,
        -- 返回二维码相关参数 check 会一并携带返回
        options = {
            client_id = client_id
        },
        err_code = 200,
        err_message = ""
    })

end


-- 检查二维码登录状态
function plugin.login_qrcode_check(pAccountInfo, pUserInfo, pParams)
    local vParams = json.decode(pParams)
    local vAccountInfo = json.decode(pAccountInfo)
    local vAccountOption = json.decode(vAccountInfo.options)
    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vAccountOption.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end

    local apiUri = string.format('%s/api/login/check', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("client_id=%s", vParams.client_id),
        timeout = "30s",

    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end
    if returnInfo.code ~= 200 then
        if returnInfo.code == 201 then
            return json.encode({
                err_code = 201,
                err_message = "请扫描二维码登录"
            })
        end
        if returnInfo.code == 408 then
            return json.encode({
                err_code = 408,
                err_message = "等待确认"
            })
        end

        return json.encode({
            err_code = 500,
            err_message = returnInfo.message
        })
    end

    -- 设置客户端client_id
    helper.channel_account_set_option(vAccountInfo.id,"client_id",vParams.client_id)

    return json.encode({
        err_code = 200,
        err_message = string.format('登录成功')
    })

end
