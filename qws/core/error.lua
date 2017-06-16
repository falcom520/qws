-- Copyright (C) 2016-2017 Falcon.C(falcom520@gmail.com)
--
--
local config    = require "qws.config.config"
local template  = require "qws.vendor.template"
local find      = string.find

local _M = {}

local TYPE_PLAIN = "text/plain"
local TYPE_JSON = "application/json"
local TYPE_HTML = "text/html"

local msg = {
    s400 = "Bad Request",
    s401 = "Unauthorized",
    s403 = "Forbidden",
    s404 = "Not Found",
    s405 = "Menthod Not Allowed",
    s500 = "Internal Server Error",
    s502 = "Bad Gateway",
    s503 = "Service Unavailable",
    s504 = "Gateway Timeout",
}

local function send(ngx,status,message)
    local status = status or ngx.status
    local _msg = message or msg["s"..status]

    local accept_header = ngx.req.get_headers()["accept"]
    local content_type

    if find(accept_header,TYPE_HTML,nil,true) then
        content_type = TYPE_HTML
    elseif find(accept_header,TYPE_PLAIN,nil,true) then
        content_type = TYPE_PLAIN
    elseif find(accept_header,TYPE_JSON,nil,true) then
        content_type = TYPE_JSON
    else
        content_type = TYPE_PLAIN
    end


    ngx.header["Server"] = config.VER
    ngx.header["Content-Type"] = content_type..";charset=utf-8"

    if content_type ~= TYPE_JSON then

        local message = {message = _msg,status = status,content_type = content_type,ver = config.VER}
        local view = "error.html"
        ngx.var.template_root = config.TEMPLATE_ROOT
        template.render(view,message)
    else
        local cjson = require "cjson"
        local message = {errMsg = _msg,errCode = status}
        ngx.say(cjson.encode(message))

        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
end

function _M:run(ngx)
    return send(ngx)
end

function _M:send(status,message)
    return send(ngx,status,message)
end

return _M
