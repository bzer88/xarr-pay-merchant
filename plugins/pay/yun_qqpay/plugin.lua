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

PAY_CHANNEL_CODE_YUN_QQPAY = "yun_qqpay"
--- 插件信息
plugin = {
    info = {
        name = PAY_CHANNEL_CODE_YUN_QQPAY,
        title = 'QQ钱包-Y',
        author = '萌新',
        description = "QQ钱包-Y 仅供学习写法,切勿使用",
        link = 'https://blog.52nyg.com/',
        version = "1.0.0",
        -- 最小支持主程序版本号
        min_main_version = "1.3.8",
        -- 支持支付类型
        channels = {
            qqpay = {
                {
                    label = '扫码免挂',
                    value = PAY_CHANNEL_CODE_YUN_QQPAY,
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
    if error_message ~= nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    print(response.body)
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
    for i, v in ipairs(returnInfo.data.list) do

        if v.action_type == "34" and  v.type =="13" and v.subject_name == "转账收入" then
            -- 推送外部订单
            plugin.parseMsg(vAccountInfo, v,returnInfo.data.uin)

        end
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('在线')
    })

end

function plugin.parseMsg(vAccountInfo, v,uin)
    local amount = tonumber(v.amount)
    if  amount <= 0 then
        goto continue
    end

    -- 判断第三方订单是否存在
    local exist = orderPayHelper.third_order_exist({
        pay_type = "qqpay",
        channel_code = PAY_CHANNEL_CODE_YUN_QQPAY,
        uid = vAccountInfo.uid,
        account_id = vAccountInfo.id,
        third_account =uin,
        third_order_id = v.trans_id
    })
    if exist then
        goto continue
    end

    if v.trans_memo then
        v.trans_memo = string.gsub(v.trans_memo, "请勿添加备注-", "")
    end

    -- 录入数据
    local insertId = orderPayHelper.third_order_insert({
        pay_type = "qqpay",
        channel_code = PAY_CHANNEL_CODE_YUN_QQPAY,
        uid = vAccountInfo.uid,
        account_id = vAccountInfo.id,

        ["buyer_id"] = "",
        ["buyer_name"] = "",
        third_order_id = v.trans_id,
        third_account=uin,
        ["amount"] = amount,
        ["remark"] = v.desc,
        ["trans_time"] = helper.datetime_to_timestamp(v.modify_time),
        ["type"] = v.type,
        ["out_order_id"] = "",

    })

    -- 录入失败
    if insertId <= 0 then
        print("外部订单插入失败",v.trans_id)
        goto continue
    end

    -- 录入成功
    local err_code, err_message = orderPayHelper.third_order_report(insertId)
    if err_code == 200 then
        print("订单上报成功:" .. err_message,v.alipay_order_no,v.trans_amount)
    else
        print("订单上报失败:" .. err_message,v.alipay_order_no,v.trans_amount)
    end

    -- 尾部
    :: continue ::

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

    local client_id = returnInfo.data.client_id


    -- 2. 获取登录二维码
    apiUri = string.format('%s/api/login/qrcode', serverAddress)
    response, error_message = http.request("POST", apiUri, {
        query = string.format("client_id=%s", client_id),
        timeout = "30s",
    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求获取登录二维码错误: %v', error_message)
        })
    end

    returnInfo = json.decode(response.body)
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
        return json.encode({
            err_code = returnInfo.code ,
            err_message = returnInfo.message
        })
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('登录成功')
    })

end
