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

PAY_CHANNEL_CODE_YUN_WECHAT_XD = "yun_wechat_xd"
--- 插件信息
plugin = {
    info = {
        name = PAY_CHANNEL_CODE_YUN_WECHAT_XD,
        title = '微信-XD',
        author = '闲蛋网',
        description = "微信-XD",
        link = 'https://www.xdau.cn/',
        version = "1.0.2",
        -- 最小支持主程序版本号
        min_main_version = "1.3.8",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = 'windows云端',
                    value = PAY_CHANNEL_CODE_YUN_WECHAT_XD,
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
            detection_interval = 3,
            detection_type = "cron", --- order 单订单检查 cron 定时执行任务
            -- 配置项
            --[[options = {
                {
                    title = "云端地址", placeholder = "多个以英文逗号[,]分割", key = "host", default = "https://api.xxx.com"
                },
            }]]
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
        return json.encode({
            err_code = 500,
            err_message = "未登录"
        })
    end

    local bindTokeInfo = json.decode(vParams.bind_token)

    -- 获取服务端地址
    local serverAddress = helper.channel_gateway_addr(vParams.gateway)
    if serverAddress == "" then
        return json.encode({
            err_code = 500,
            err_message = "暂未配置支付网关"
        })
    end
    local apiUri = string.format('%s/WeChat_Pc/IsLoginStatus', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", bindTokeInfo.uid),
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

    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end

    if returnInfo.code ~= "1" then
        -- 设置离线
        helper.channel_account_offline(vAccountInfo.id)
        -- 取消登录数据
        helper.channel_account_set_option(vAccountInfo.id,"bind_token","")


        if returnInfo.code == "0" then
            return json.encode({
                err_code = 201,
                err_message = "请扫描二维码登录"
            })
        end
        if returnInfo.code == "-1" then
            return json.encode({
                err_code = 500,
                err_message = "uid参数错误"
            })
        end
        if returnInfo.code == "-2" then
            return json.encode({
                err_code = 500,
                err_message = "没有找到Uid"
            })
        end

        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    -- 如果离线状态 则设置为在线
    if vAccountInfo.online ~= 1 then
        -- 设置在线
        helper.channel_account_online(vAccountInfo.id)
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('在线')
    })

end


-- 二维码登录
function plugin.login_qrcode(pAccountInfo, pUserInfo, pParams)
    local vParams = json.decode(pParams)
    local vUserInfo = json.decode(pUserInfo)

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

    -- 1. 创建客户端
    local apiUri = string.format('%s/WeChat_Pc/CreateID', serverAddress)
    local req = {
        ["data"] = helper.base64_encode(json.encode({ ["site"] = vParams['domain_url'], ["pid"] = vUserInfo.id, ["key"] = vUserInfo.app_secret }))
    }

    print("请求地址",apiUri,"请求内容",funcs.table_http_query(req))

    local response, error_message = http.request("POST", apiUri, {
        query = funcs.table_http_query(req),
        timeout = "30s",

    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求错误: %v', error_message)
        })
    end

    local returnInfo = json.decode(response.body)
    print("创建客户端返回内容",response.body)
    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误,响应内容: %v', response.body)
        })
    end
    if returnInfo.code ~= "1" then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态码 响应内容: %v', response.body)
        })
    end

    local uid = returnInfo.uid


    -- 2. 获取登录二维码
    apiUri = string.format('%s/WeChat_Pc/QRCode', serverAddress)
    response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", uid),
        timeout = "30s",
    })
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求获取登录二维码错误: %v', error_message)
        })
    end

    returnInfo = json.decode(response.body)
    print("创建二维码返回内容",response.body)
    if returnInfo.code ~= "1" then
        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    return json.encode({
        -- 返回二维码
        qrcode = returnInfo.url,
        -- 返回二维码相关参数 check 会一并携带返回
        options = {
            uid = uid
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
    local apiUri = string.format('%s/WeChat_Pc/IsLoginStatus', serverAddress)
    local response, error_message = http.request("POST", apiUri, {
        query = string.format("uid=%s", vParams.uid),
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
    if returnInfo.code ~= "1" then
        if returnInfo.code == "0" then
            return json.encode({
                err_code = 201,
                err_message = "请扫描二维码登录"
            })
        end
        if returnInfo.code == "-1" then
            return json.encode({
                err_code = 500,
                err_message = "uid参数错误"
            })
        end
        if returnInfo.code == "-2" then
            return json.encode({
                err_code = 500,
                err_message = "没有找到Uid"
            })
        end

        return json.encode({
            err_code = 500,
            err_message = string.format('返回错误状态吗: %v', response.body)
        })
    end

    return json.encode({
        err_code = 200,
        err_message = string.format('登录成功')
    })

end
