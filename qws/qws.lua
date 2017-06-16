-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local singleton = require "qws.core.singleton"
local handler   = require "qws.core.handler"
local db        = require "qws.core.db"
local cache     = require "qws.dao.cache"
local util      = require "qws.tools.util"
local response  = require "qws.tools.response"
local config    = require "qws.config.config"
local cjson     = require "cjson"

local _M = {}

local option = {
    host = config.MYSQL_SERVER.host,
    port = config.MYSQL_SERVER.port,
    username = config.MYSQL_SERVER.username,
    password = config.MYSQL_SERVER.password,
    dbname = config.MYSQL_SERVER.dbname,
    charset = config.MYSQL_SERVER.charset,
}

--init config data
function _M.init()

    -- load router data and upstream
    local dao = db:new(option)
    singleton.dao = dao

    -- load plugins
    local plugin = require "qws.plugins.load_plugins"
    singleton.plugins = plugin:load_plugins()

    assert(handler.build_upstream())
end

function _M.init_worker()

    singleton.dao = db:new(option)
    handler.init_worker()

    --init load plugin data
    for _,plugin in ipairs(singleton.plugins) do
        plugin.handler:init_worker()
    end
end

function _M.balancer()
    --select peer and set_current_peer by ngx.req.get_headers()["Host"] and ring_balance/ip_hash/rr
    local balancer = require "ngx.balancer"

    local addr = ngx.ctx.balancer_address
    --error("BALANCER->"..cjson.encode(addr))
    --[[
    if addr.tries > 1 then
        addr.failures = addr.failures or {}
        local state,code = get_last_failure()
        addr.failures[addr.tries-1] = {name = state,code = code}
    else
        local retries = addr.retries
        if retries > 0 then
            balancer.set_more_tries(retries)
        end
    end
    --]]
    --util.wlog("BALANCER->"..cjson.encode(addr))

    local ok,err = balancer.set_current_peer(addr.ip,addr.port)
    if not ok then
        ngx.log(ngx.ERR,"failed to set the current peer (address:",tostring(addr.ip)," port:",tostring(addr.port),") ",tostring(err))
        return response:send(500,"Server Internal Error")
    end
    ok,err = balancer.set_timeouts(addr.connect_timeout/1000,addr.send_timeout/1000,addr.read_timeout/1000)
    if not ok then
        ngx.log(ngx.ERR,"could not set upstream timeouts: ",err)
    end
end

function _M.ssl_certificate()
    handler.ssl_certificate()
end

function _M.access()
    handler.access_before()

    -- load plugin data
    for _,plugin in pairs(singleton.plugins) do
        plugin.handler:access()
    end

    handler.access_after()
end

function _M.header_filter()
    handler.header_filter_before()
    --load plugin data
    for _,plugin in pairs(singleton.plugins) do
        plugin.handler:header_filter()
    end
    handler.header_filter_after()
end

function _M.body_filter()
   for _,plugin in pairs(singleton.plugins) do
        plugin.handler:body_filter()
   end
   handler.body_filter()
end

function _M.log()
    for _,plugin in pairs(singleton.plugins) do
        plugin.handler:log()
    end
    handler.log()
end

return _M
