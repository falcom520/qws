-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local err_handle = require "qws.core.error"

local _M = {}

function _M:send(status,message)
    return err_handle:send(status,message)   
end


function _M:send_json(data)
    ngx.header["Content-Type"] = "application/json;charset=utf-8"
    local cjson = require "cjson"
    return ngx.say(cjson.encode(data))
end
return _M
