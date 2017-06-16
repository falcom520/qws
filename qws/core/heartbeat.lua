-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local upstream      = require "qws.dao.upstream"
local flush_cache   = require "qws.dao.flush_cache"
local cache         = require "qws.dao.cache"
local util          = require "qws.tools.util"
local cjson         = require "cjson"

local re_find = string.find
local str_sub = string.sub
local log   = ngx.log
local ERR   = ngx.ERR
local WARN  = ngx.WARN
local tcp   = ngx.socket.tcp
local timer_at  = ngx.timer.at

local _M = {
    STATUS_OK = 0,STATUS_UNSTABLE = 1,STATUS_ERR = 2
}

local timeout = 2 -- 2s
local HEARTBEAT_INTERVAL = 4

local KEY_HEARTBEAT_CHECK = "key_heartbeat_check"

local function check_tcp(host,port)
    local ip,err = util.dns_query(host)
    if not ip then
        return _M.STATUS_ERR,err
    end
    local sock = tcp()
    sock:settimeout(timeout * 3000)
    local ok,err = sock:connect(ip,port)
    if not ok then
        return _M.STATUS_ERR,err
    end
    sock:setkeepalive()
    return _M.STATUS_OK
end


-- opts = {query = "GET /status HTTP/1.1\r\nHost: localhost\r\n\r\n"}
local function check_http(host,port,opts)

    local id = host..":"..port
    local sock,err = tcp()
    if not sock then
        return _M.STATUS_ERR,err
    end

    sock:settimeout(timeout * 1000)
    local ok,err = sock:connect(host,port)
    if not ok then
        return _M.STATUS_ERR,err
    end

    local opts = opts or {}

    local req = opts.query
    if not req then
        sock:setkeepalive()
        return _M.STATUS_OK
    end

    local bytes,err = sock:send(req)
    if not bytes then
        return _M.STATUS_ERR,err
    end

    local readline = sock:receiveuntil("\r\n")
    local status_line,err = readline()
    if not status_line then
        return _M.STATUS_ERR,err
    end
    local from,to,err = re_find(status_line,[[^HTTP/\d+\.\d+\s+(\d+)]], "joi", nil, 1)
    if not from then
        return _M.STATUS_ERR,err
    end
    local status = tonumber(str_sub(status_line,from,to))
    if status ~= 200 then
        return _M.STATUS_UNSTABLE,"bad status code"
    end

    sock:setkeepalive()
    return _M.STATUS_OK
end

local function get_lock(key,exptime)
    local ok,err = cache:safe_add(key,true,exptime - 0.001)
    if not ok and err ~= "exists" then
        log(ERR,"could not get lock err->",err)
    end
    return ok
end

local function create_timer(...)
    local ok,err = timer_at(...)
    if not ok then
        log(ERR,"create timer err: ",err)
    end
end

local function run()

    local servers = upstream:get_servers_all()
    if #servers == 0 then
        return
    end

    for k,v in pairs(servers) do
        local status,err = check_tcp(v.server,v.port)
        if status ~= v.status then
            -- update flush cache
            local upstream_info = upstream:get_upstream_info(v.upstream_id)
            flush_cache:upstream(upstream_info["host"])

            -- mysql server status update
            local data = {status = status}
            upstream:update_servers(v.server_id,data)
        end
    end
end

local function heartbeat_handler(premature)
    if premature then
        return 
    end
    create_timer(HEARTBEAT_INTERVAL,heartbeat_handler)
    if not get_lock(KEY_HEARTBEAT_CHECK,HEARTBEAT_INTERVAL) then
        return
    end
    
    run()
end

function _M:init_worker()
    create_timer(HEARTBEAT_INTERVAL,heartbeat_handler)
end

return _M
