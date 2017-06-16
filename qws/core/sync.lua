-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local upstream_dao = require "qws.dao.upstream"
local cache        = require "qws.dao.cache"
local singleton    = require "qws.core.singleton"
local util         = require "qws.tools.util"
local cjson        = require "cjson"

local _M = {}
local timer_at = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERROR


local SYNC_INTERVAL = 5

local function create_timer(...)
    local ok,err = timer_at(...)
    if not ok then
        log(ERR,"create timer err: ",err)
    end
end

local function load_upstream()
    local time = util.time() - 9
    local upstreams = upstream_dao:get_upstream_by_updatetime(time)
    --util.wlog("get_upstream_by_updatetime -> "..cjson.encode(upstreams))
    if #upstreams == 0 then
        return false
    end
    for k,v in pairs(upstreams) do
        if v.is_forbidden == 1 then
            cache:del("U:"..v.host)
            local router_id = cache:get("R:"..v.upstream_id)
            if router_id ~= false then
                cache:del("R:"..v.upstream_id)
                for k1,v1 in pairs(router_id) do
                    cache:del("R:"..v1)
                end
            end
            local server_id = cache:get("S:"..v.upstream_id)
            if server_id ~= false then
                cache:del("S:"..v.upstream_id)
                for k1,v1 in pairs(server_id) do
                    cache:del("S:"..v1)
                end
            end
        else
            local upstream = cache:get("U:"..v.host)
            cache:set("U:"..v.host,v)
            -- load Server
            local server = upstream_dao:get_servers(v.upstream_id)
            if server and #server > 0 then
                local server_id = {}
                for k1,v1 in pairs(server) do
                    key = "S:"..v1.server_id
                    cache:set(key,v1)
                    if v1.status == 0 then
                        server_id[#server_id+1] = v1.server_id
                    end
                end
                -- SERVER key S:upstream_id
                key = "S:"..v.upstream_id
                cache:set(key,server_id)
            else
                cache:del("S:"..v.upstream_id)
            end

            -- load Router
            routers,err = upstream_dao:get_router(v.upstream_id)
            if routers and #routers > 0 then
                --ROUTER key R:router_id
                local router_id = {}
                for k1,v1 in pairs(routers) do
                    key = "R:"..v1.router_id
                    cache:set(key,v1)
                    router_id[k1] = v1.router_id
                end

                -- ROUTER key R:upstream_id
                key = "R:"..v.upstream_id
                cache:set(key,router_id)
            else
                cache:del("R:"..v.upstream_id)
            end
        end
    end
end


local function load_server()
    local time = util.time() - 10
    local servers = upstream_dao:get_server_by_updatetime(time)
    --util.wlog("get_servers_by_updatetime -> "..cjson.encode(servers))
    if not servers or #servers == 0 then
        return false
    end

    for k,v in pairs(servers) do
        if v.is_forbidden == 1 then
            local s = cache:get("S:"..v.server_id) 
            if s ~= false then
                cache:del("S:"..v.server_id)
            end
            local u_server_id = cache:get("S:"..v.upstream_id)
            if u_server_id ~= false then
                u_server_id = util.remove_array(u_server_id,v.server_id)
                cache:set("S:"..v.upstream_id,u_server_id)
            end
        else
            if v.status == 0 then
                local s = cache:get("S:"..v.server_id)
                if s == false then -- add
                    local u_server_id = cache:get("S:"..v.upstream_id)
                    if u_server_id ~= false then
                        u_server_id[#u_server_id+1] = v.server_id
                    else
                        u_server_id = {}
                        u_server_id[1] = v.server_id
                    end
                    cache:set("S:"..v.upstream_id,u_server_id)
                end
                cache:set("S:"..v.server_id,v)
            end
        end
    end
end


local function load_router()
    local time = util.time() - 10
    local routers = upstream_dao:get_router_by_updatetime(time)
    --util.wlog("get_router_by_updatetime -> "..cjson.encode(routers).." time->"..util.timetostr(time))
    if not routers or #routers == 0 then
        return false
    end
    for k,v in pairs(routers) do
        if v.is_forbidden == 1 then
            local r = cache:get("R:"..v.router_id)
            if r ~= false then
                cache:del("R:"..v.router_id)
            end
            local u_router_id = cache:get("R:"..v.upstream_id)
            if u_router_id ~= false then
                u_router_id = util.remove_array(u_router_id,v.router_id)
                cache:set("R:"..v.upstream_id,u_router_id)
            end
            --util.wlog(cjson.encode(u_router_id).." v->"..cjson.encode(v))
        else
            cache:set("R:"..v.router_id,v)
            local u_router_id = cache:get("R:"..v.upstream_id)
            if u_router_id ~= false then
                u_router_id[#u_router_id+1] = v.router_id
            else
                u_router_id = {}
                u_router_id[1] = v.router_id
            end
            cache:set("R:"..v.upstream_id,u_router_id)
        end
    end
end

local function get_lock(key,exptime)
    local ok,err = cache:safe_add(key,true,exptime - 0.001)
    if not ok and err ~= "exists" then
        log(ERR,"could not get lock err->",err)
    end
    return ok
end

local function sync_handler(premature)
    if premature then
        return 
    end
    create_timer(SYNC_INTERVAL,sync_handler)

    if not get_lock("SYNC_INTERVAL",SYNC_INTERVAL) then
        return
    end

    -- update upstream
    load_upstream()
    load_server()
    load_router()
end


function _M:init_worker()
    create_timer(SYNC_INTERVAL,sync_handler)
end

return _M
