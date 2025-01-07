local funcs = require("funcs")
local http = require("http")
local json = require("json")
local xml = require("xml")
local helper = require("helper")
local orderHelper = require("orderHelper")
--local log = require("log")

PAY_CHANNEL_CODE_YUN_WECHAT_IMAC = "yun_wechat_imac"
--- 插件信息
plugin = {
    info = {
        name = PAY_CHANNEL_CODE_YUN_WECHAT_IMAC,
        title = '微信-IMAC',
        author = '萌新',
        description = "微信-IMAC 仅供学习写法,切勿使用",
        link = 'https://blog.52nyg.com/',
        version = "1.4.4",
        -- 最小支持主程序版本号
        min_main_version = "1.4.0",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = '微信-IMAC',
                    value = PAY_CHANNEL_CODE_YUN_WECHAT_IMAC,
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
        },
    })
end

function plugin.create(pOrderInfo, pluginOptions, pAccountInfo)

    local vParams = json.decode(pluginOptions)
    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)
    local vAccountInfo = json.decode(pAccountInfo)
    local bindTokeInfo = json.decode(vParams.bind_token)

    if vAccountInfo.online ~= 1 then
        return json.encode({
            err_code = 500,
            err_message = "账号已离线"
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

    -- 创建收款二维码
    --http://test-imac.02id.com/api/Payment/WXTransferSetF2FFee
    --
    local apiUri = string.format('%s/api/Payment/WXTransferSetF2FFee', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        body = json.encode({
            Guid = bindTokeInfo.client_id,
            Description = orderInfo.order_id,
            Fee = orderInfo.trade_amount,
        }),
        timeout = "30s",
        headers = {
            ["content-type"] = "application/json"
        },
    })

    if response.status_code ~= 200 then
        if vAccountInfo.online == 1 then
            -- 设置离线
            helper.channel_account_offline(vAccountInfo.id)
        end
        return json.encode({
            err_code = 500,
            err_message = "创建订单失败"
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

    if returnInfo.code ~= 0 or returnInfo.data.baseResponse.ret ~= 0 then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = returnInfo.data.baseResponse.errMsg.string
        })
    end

    -- 判断是否创建了二维码
    if returnInfo.data.reqText ~= nil and returnInfo.data.reqText.buffer ~= nil then
        local reqText = json.decode(returnInfo.data.reqText.buffer)

        if reqText ~= nil and reqText.pay_url ~= "" and reqText.retmsg == "ok" then
            return json.encode({
                type = "qrcode",
                qrcode = reqText.pay_url,
                url = "",
                content = "",
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        end
    end
    return json.encode({
        err_code = 500,
        err_message = "创建收款码失败"
    })


end

-- 定时任务
function plugin.cron(pAccountInfo, pPluginOptions)
    local vAccountInfo = json.decode(pAccountInfo)
    local vParams = json.decode(vAccountInfo.options)

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

    -- 心跳
    local apiUri = string.format('%s/api/User/WXGetProfile', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        body = json.encode({
            Guid = bindTokeInfo.client_id,
        }),
        timeout = "30s",
        headers = {
            ["content-type"] = "application/json"
        },
    })

    --log.debug("心跳", response.status_code)

    -- 获取账单
    apiUri = string.format('%s/api/Message/WXSyncMsg', serverAddress)
    response, error_message = http.request("POST", apiUri, {
        body = json.encode({
            Guid = bindTokeInfo.client_id,
        }), timeout = "30s",
        headers = {
            ["content-type"] = "application/json"
        },

    })
    --log.debug("同步消息", response.status_code)

    if response.status_code ~= 200 then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', response.status_code)
        })
    end

    --print("同步账单", response.body)
    local returnInfo = json.decode(response.body)

    if returnInfo.code == nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end

    if returnInfo.code ~= 0 or returnInfo.data.Ret ~= 0 then
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
    if returnInfo.data.Result then
        for i, msg in ipairs(returnInfo.data.Result.AddMsgs) do
            if msg.MsgType == 49 then
                --log.debug("消息来了")
                -- 推送外部订单
                plugin.parseMsg(vAccountInfo, msg)

            end
        end
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('处理完成')
    })

end

function plugin.parseMsg(vAccountInfo, msg)
    -- 解析xml
    local msgData = msg.Content.String

    local appMsg = msgData:match("<appmsg([%W%w]+)</appmsg>")
    -- 订单号
    local remark = appMsg:match("<des>%s*<!%[CDATA%[[%w%W]+收款方备注(%d+)[%w%W]+<%/des>%s+<action>")
    -- 发送方
    local title = msgData:match("<appname><!%[CDATA%[(.*)%]%]><%/appname>")
    local content = msgData:match("<title><!%[CDATA%[(.*)%]%]><%/title>%s+<des")
    --log.debug("消息内容",msgData)
    --log.debug("解析消息",  remark, title,content)

    local rules = {
        {
            TitleReg = "微信收款助手",
            ContentReg = "微信支付收款(?<amount>[\\d\\.]+)元(\\(([新老]顾客)?(朋友)?到店\\))?",
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
        local titleMatched = helper.regexp_match(title, v.TitleReg)
        if titleMatched then
            -- 调用正则
            local matched, matchGroups = helper.regexp_match_group(content, v.ContentReg)

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
                        channel_code = PAY_CHANNEL_CODE_YUN_WECHAT_IMAC,
                        pay_time = msg.CreateTime,
                        out_order_id = remark,
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

    -- 1. 创建客户端
    local apiUri = string.format('%s/api/Client/WXCreate', serverAddress)

    local req = {
        Terminal = 3,
        WxData = "data",
        Brand = "mac",
        Name = "mac-tegic",
        Imei = "string",
        Mac = "mac"
    };
    local response, error_message = http.request("POST", apiUri, {
        timeout = "30s",
        body = json.encode(req),
        headers = {
            ["content-type"] = "application/json"
        },

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
    if returnInfo.code ~= 0 then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态码 响应内容: %v', response.body)
        })
    end

    local client_id = returnInfo.data.Guid


    -- 2. 获取登录二维码
    apiUri = string.format('%s/api/Login/WXGetLoginQrcode', serverAddress)
    response, error_message = http.request("POST", apiUri, {
        body = json.encode({
            Guid = client_id
        }),
        headers = {
            ["content-type"] = "application/json"
        },
        timeout = "30s",
    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求获取登录二维码错误: %v', error_message)
        })
    end

    returnInfo = json.decode(response.body)
    if returnInfo.code ~= 0 then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    local qrcode = returnInfo.data.qrcode
    if qrcode ~= "" then
        qrcode = "data:image/png;base64," .. qrcode
    end

    return json.encode({
        -- 返回二维码
        qrcode = qrcode,
        -- 返回二维码相关参数 check 会一并携带返回
        options = {
            client_id = client_id,
            uuid = returnInfo.data.uuid,
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

    local apiUri = string.format('%s/api/Login/WXCheckLoginQrcode', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        body = json.encode({
            Guid = vParams.client_id,
            Uuid = vParams.uuid,
        }),
        timeout = "30s",

        headers = {
            ["content-type"] = "application/json"
        },
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
    if returnInfo.code ~= 0 then
        return json.encode({
            err_code = 500,
            err_message = returnInfo.message
        })
    end

    if returnInfo.data.state == 1 then
        return json.encode({
            err_code = 201,
            err_message = string.format('扫码中')
        })
    end

    if returnInfo.data.state == 2 then
        -- 开始手动登录
        apiUri = string.format('%s/api/Login/WXSecLoginManual', serverAddress)

        response, error_message = http.request("POST", apiUri, {
            body = json.encode({
                Guid = vParams.client_id,
                UserName = returnInfo.data.wxid,
                Password = returnInfo.data.wxnewpass,
                Channel = 1,
            }),
            timeout = "30s",

            headers = {
                ["content-type"] = "application/json"
            },
        })

        if error_message ~= nil then
            return json.encode({
                err_code = 500,
                err_message = string.format('二维码扫码成功 但登录请求错误: %v', error_message)
            })
        end

        returnInfo = json.decode(response.body)
        if returnInfo == nil then
            return json.encode({
                err_code = 500,
                err_message = string.format('登录返回错误: %v', response.body)
            })
        end

        if returnInfo.code ~= 0 then
            return json.encode({
                err_code = 500,
                err_message = returnInfo.message
            })
        end

        if returnInfo.data.baseResponse.ret ~= 0 then
            return json.encode({
                err_code = 500,
                err_message = returnInfo.data.baseResponse.errMsg.string
            })
        end

        return json.encode({
            err_code = 200,
            err_message = string.format('登录成功 %s', returnInfo.data.accountInfo.wxid)
        })
    end

    return json.encode({
        err_code = 201,
        err_message = string.format('等待扫码')
    })

end
