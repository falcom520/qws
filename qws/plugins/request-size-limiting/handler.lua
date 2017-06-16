-- Copyright (C) 2016-2017 topoto.cn, Inc.
--

local base      = require "qws.plugins.base_plugin"
local response  = require "qws.tools.response"
local util      = require "qws.tools.util"

local _M = base:extend()
local MB = 2^4
local allowed_payload_size = 1

local function check_size(length,allowed_size,headers)
    local allowed_bytes_size = allowed_size * MB
    if length > allowed_bytes_size then
        if headers.expect and util.trim(headers.expect:lower()) == "100-continue" then
            return response:send(417,"Request size limit exceeded.")
        else
            return response:send(413,"Request size limit exceeded.")
        end
    end
end

function _M:new()
    _M.super.new(self,"request-size-limiting")
end

function _M:access()
    _M.super.access(self)
    local headers = ngx.req.get_headers()
    local c1 = headers["content-length"]

    if c1 and tonumber(c1) then
        check_size(tonumber(c1),allowed_payload_size,headers)
    else
        ngx.req.read_body()
        local data = ngx.req.get_body_data()
        if data then
            check_size(#data,allowed_payload_size,headers)
        end
    end
end

return _M
