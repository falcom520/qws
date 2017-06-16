-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local Object = require "qws.vendor.classic"
local _M = Object:extend()

function _M:new(name)
    self._name = name
end

function _M:init_worker()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": init_worker")
end

function _M:certificate()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": certificate")
end

function _M:access()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": access")
end

function _M:header_filter()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": header_filter")
end

function _M:body_filter()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": body_filter")
end

function _M:log()
    ngx.log(ngx.DEBUG," executing plugin \""..self._name.."\": log")
end

return _M
