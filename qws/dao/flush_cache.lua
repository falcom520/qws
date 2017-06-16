-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local singleton = require "qws.core.singleton"
local cache     = require "qws.dao.cache"
local util      = require "qws.tools.util"

local cjson = require "cjson"

local _M = {}

function _M:upstream(host)
    local host = host or nil
    if not host then
        return nil,""
    end
    local dao = singleton.dao
    assert(dao,"connect to db fail.")

    --read upstream info
    local sql = "select upstream_id,name,scheme,host,lb,connect_timeout,send_timeout,read_timeout,is_forbidden from upstream where host = "..ngx.quote_sql_str(host)
    dao:query(sql)
    local result = dao:store_result()
    local upstream = result:fetch("a")
    result:free()
    if not upstream then
        --deleted upstream info
        local upstreams = cache:get("U:"..host)
        if upstreams then
            cache:del("U:"..host)
            for i,v in pairs(upstreams.server_id) do
                cache:del("S:"..v)
            end

            for i,v in pairs(upstreams.router_id) do
                cache:del("R:"..v)
            end
        end
        return nil,""
    end
    --util.wlog("read_upstream_info->"..cjson.encode(upstream))

    local upstream_id = upstream["upstream_id"]

    -- read server list
    sql = "select server_id,upstream_id,server,port,weight,fails,status,is_forbidden from upstream_server where upstream_id = "..ngx.quote_sql_str(upstream_id)
    dao:query(sql)
    result = dao:store_result()
    local servers = {}
    if result then
        ii = 1
        for i,server_id,upstream_id,server,port,weight,fails,status,is_forbidden in result:rows() do
            if tonumber(is_forbidden) == 1 or tonumber(status) ~= 0 then
                cache:del("S:"..server_id)
            else
                local _server = {
                    server_id   = server_id,
                    server      = server,
                    port        = port,
                    weight      = weight,
                    fails       = fails,
                    status      = tonumber(status),
                    is_forbidden = tonumber(is_forbidden),
                }
                cache:set("S:"..server_id,_server)
                servers[ii] = server_id
                ii = ii + 1
            end
        end
    end
    result:free()
    --util.wlog("read_servers_info->"..cjson.encode(servers))


    -- read router list
    sql = "select router_id,upstream_id,server_id,rule,uri,new_uri,is_forbidden from router where upstream_id = "..ngx.quote_sql_str(upstream_id)
    dao:query(sql)
    result = dao:store_result()
    local routers = {}
    if result then
        ii = 1
        for i,router_id,upstream_id,server_id,rule,uri,new_uri,is_forbidden in result:rows() do
            if tonumber(is_forbidden) == 1 then
                cache:del("R:"..router_id)
            else
                local _router = {
                    router_id = router_id,
                    uri       = uri,
                    new_uri   = new_uri,
                    rule      = cjson.decode(rule) or {},
                    server_id = cjson.decode(server_id) or {}
                }
                cache:set("R:"..router_id,_router)
                routers[ii]  = router_id
                ii = ii + 1
            end
        end
    end
    --util.wlog("read_router_info->"..cjson.encode(routers))

    if tonumber(upstream["is_forbidden"]) == 1 then
        cache:del("U:"..upstream['host'])

        for i,v in pairs(servers) do
            cache:del("S:"..v)
        end

        for i,v in pairs(routers) do
            cache:del("R:"..v)
        end
    else
        upstream.server_id = servers
        upstream.router_id = routers
        cache:set("U:"..upstream['host'],upstream)
    end

end



return _M
