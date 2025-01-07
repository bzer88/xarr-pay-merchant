-- 载入插件
local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local orderPayHelper = require("orderPayHelper")

PAY_WXPAY_JSAPI = "wxpay_jsapi"

--- 插件信息
plugin = {
    info = {
        name = PAY_WXPAY_JSAPI,
        title = '微信-JSAPI',
        author = '官方',
        link = 'https://www.xarr.cn',
        description = "微信官方支付-JSAPI",
        version = "1.4.5",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = '微信-JSAPI',
                    value = PAY_WXPAY_JSAPI
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
                label = '公众号ID',
                type = 'input',
                default = "",
                placeholder = "公众号ID",
                options = {
                    tip = '如: wxxxxx',
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
                label = '公众号Secret',
                type = 'input',
                default = "",
                placeholder = "公众号Secret",
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

function plugin.create(pOrderInfo, pPluginOptions, ...)
    local args = { ... }
    local pluginOptions = json.decode(pPluginOptions)

    local orderInfo = json.decode(pOrderInfo)
    if orderInfo.third_open_id == "" then
        return json.encode({
            -- 非立即创建的订单,前置条件
            type = 'pre',
            qrcode_use_short_url = 1,
            options= {
                -- toApp 重新创建订单
                to_app_create = 1,

                -- 需要订单授权微信ID
                need_wechat_openid = 1,
                -- 使用自定义的微信公众号
                use_wechat_self = 1,
                wechat_app_id = pluginOptions.appid,
                wechat_app_secret = pluginOptions.app_secret,
            },
            err_code = 200,
            err_message = "需要授权获取OpenId"
        })
    end

    local err_code, err_message, result = orderPayHelper.wxpay_jsapi_create(pOrderInfo, pPluginOptions)

    if err_code ~= 200 then
        return json.encode({
            type = 'error',
            err_code = 500,
            err_message = err_message
        })
    elseif err_code == 200 then
        return json.encode({
            type = "html",
            qrcode = "",
            qrcode_use_short_url = 1,
            url = "",
            content = plugin.buildHtml(orderInfo.order_id,result,orderInfo.return_url),
            --options= {
                -- HTML 支持重新渲染
                --html_render = 1,
--            },
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
    local err_code, err_message, response = orderPayHelper.wxpay_jsapi_notify(request, orderInfo, pluginOptions)

    return json.encode({
        error_code = err_code,
        error_message = err_message,
        response = response,
    })

end


function plugin.buildHtml(orderId,result,redirectUri )
    return [[
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta charset="utf-8" />
    <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width">
    <title>微信支付手机版</title>
</head>
<body style="    text-align: center;">
<div class="bar bar-header bar-light" align-title="center">
	<h1 class="title">微信支付</h1>
</div>
<div class="has-header" style="padding: 5px;position: absolute;width: 100%;">
<div class="text-center" style="
    display: flex;
    align-items: center;
    flex-direction: column;">
<div class="text-center" style="font-size: 80px;
    background-color: #19ac1a;
    border-radius: 100%;
    width: 80px;
    height: 80px;
    display: flex;
    justify-content: center;
    text-align: center;
    color: white;
    align-items: center;">i</div><br>
<span>正在跳转...</span>

<script src="/plugins/wxpay_jspay/assets/js/jquery.min.js"></script>
<script src="/plugins/wxpay_jspay/assets/js/layer/layer.js"></script>
<script>
	document.body.addEventListener('touchmove', function (event) {
		event.preventDefault();
	},{ passive: false });
    //调用微信JS api 支付
	function jsApiCall()
	{
		WeixinJSBridge.invoke(
			'getBrandWCPayRequest',
			]].. result..[[,
			function(res){
				if(res.err_msg == "get_brand_wcpay_request:ok" ) {
					loadmsg();
				}
				//WeixinJSBridge.log(res.err_msg);
				//alert(res.err_code+res.err_desc+res.err_msg);
			}
		);
	}

	function callpay()
	{
		if (typeof WeixinJSBridge == "undefined"){
		    if( document.addEventListener ){
		        document.addEventListener('WeixinJSBridgeReady', jsApiCall, false);
		    }else if (document.attachEvent){
		        document.attachEvent('WeixinJSBridgeReady', jsApiCall);
		        document.attachEvent('onWeixinJSBridgeReady', jsApiCall);
		    }
		}else{
		    jsApiCall();
		}
	}
    // 检查是否支付完成
    function loadmsg() {
        $.ajax({
            type: "POST",
            dataType: "json",
            url: "/api/order/info",
            timeout: 10000, //ajax请求超时时间10s
            data: { order_id: "]]..orderId..[["}, //post数据
            success: function (data, textStatus) {
                //从服务器得到数据，显示数据并继续查询
                if (data.code == 200 && data.data.status == 2) {
					layer.msg('支付成功，正在跳转中...', {icon: 16,shade: 0.01,time: 15000});
                    window.location.href=']]..redirectUri..[[';
                }else{
                    setTimeout("loadmsg()", 2000);
                }
            },
            //Ajax请求超时，继续查询
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                if (textStatus == "timeout") {
                    setTimeout("loadmsg()", 1000);
                } else { //异常
                    setTimeout("loadmsg()", 3000);
                }
            }
        });
    }
    window.onload = callpay();
</script>
</div>
</div>
</body>
</html>
    ]]
end