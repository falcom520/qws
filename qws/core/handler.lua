-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local router         = require "qws.core.router"
local heartbeat      = require "qws.core.heartbeat"
local upstream       = require "qws.dao.upstream"
local cache          = require "qws.dao.cache"
local util           = require "qws.tools.util"
local response       = require "qws.tools.response"
local config         = require "qws.config.config"
local cjson          = require "cjson"

local _M = {}


function _M.build_upstream()
    local routers,err,upstreams,upstream_servers

    upstreams,err = upstream:get_upstreams()
    if not upstreams then
        return nil,"no upstream"
    end

    local key
    for i = 1,#upstreams do
        local upstream_id = upstreams[i].upstream_id

        --get upstream server list
        upstream_servers,err = upstream:get_servers(upstream_id)
        if upstream_servers and #upstream_servers > 0 then
            for k,v in pairs(upstream_servers) do
                key = "S:"..v.server_id
                cache:set(key,v)

                if not upstreams[i].server_id then
                    upstreams[i].server_id = {}
                end
                if v.status == 0 then
                    upstreams[i].server_id[#upstreams[i].server_id+1] = v.server_id
                end
            end
        end

        -- get router list
        routers,err = upstream:get_router(upstream_id)
        if routers and #routers > 0 then
            --ROUTER key R:router_id
            for k,v in pairs(routers) do
                key = "R:"..v.router_id
                cache:set(key,v)

                if not upstreams[i].router_id then
                    upstreams[i].router_id = {}
                end
                upstreams[i].router_id[k] = v.router_id
            end
        end

        --UPSTREAM key U:app1.topoto.cn
        key = "U:"..upstreams[i].host
        cache:set(key,upstreams[i])
    end
    return true
end

function _M.init_worker()

    -- sync db data change
    --sync:init_worker()

    -- heartbeat check upstream servers health status
    heartbeat:init_worker()

end

function _M.ssl_certificate()
    local ssl = require "ngx.ssl"

    local ok,err = ssl.clear_certs()
    if not ok then
        ngx.log(ngx.ERR,"could not clear existing certificate:",err)
        return ngx.exit(ngx.ERROR)
    end

    local sni,err = ssl.server_name()
    if not sni then
        sni = "qiucloud.com"
    end

    local chain,err = cache:get("SSL:"..sni)
    if not chain then

        local f,err = io.open(config.SSL_DIR.."/"..sni..".crt")
        if not f then
            ngx.log(ngx.ERR,"err: ",err)
            return ngx.exit(ngx.ERROR)
        end
        local cert = f:read("*a")
        f:close()

        local f,err = io.open(config.SSL_DIR.."/"..sni..".pem")
        if not f then
            ngx.log(ngx.ERR,"err: ",err)
            return ngx.exit(ngx.ERROR)
        end
        local key = f:read("*a")
        f:close()

        local der_cert_chain,err = ssl.cert_pem_to_der(cert)
        if not der_cert_chain then
            ngx.log(ngx.ERR,"cert pem to der error: ",err)
            return ngx.exit(ngx.ERROR)
        end

        local der_priv_key,err = ssl.priv_key_pem_to_der(key)
        if not der_priv_key then
            ngx.log(ngx.ERR,"priv key pem to der error: ",err)
            return ngx.exit(ngx.ERROR)
        end

        chain = {cert = der_cert_chain,key = der_priv_key }
        cache:set("SSL:"..sni)
    end

    local ok,err = ssl.set_der_cert(chain.cert)
    if not ok then
        ngx.log(ngx.ERR,"set der cert error: ",err)
        return ngx.exit(ngx.ERROR)
    end

    local ok,err = ssl.set_der_priv_key(chain.key)
    if not ok then
        ngx.log(ngx.ERR,"set der priv key error: ",err)
        return ngx.exit(ngx.ERROR)
    end
end

function _M.access_before()
        local ctx = ngx.ctx
        local var = ngx.var

        local method = ngx.req.get_method()
        local headers = ngx.req.get_headers()
        local host = headers["Host"] or headers["host"]

        local key
        -- get upstream info by headers.host
        local k = "U:"..host
        local upstream_info = cache:get(k)
        if not upstream_info then
            return response:send(500,"no upstream info ")
        end
        --util.wlog("ACCESS_UPSTREAM->"..cjson.encode(upstream_info))

        -- get upstream server list by upstream_id
        local upstream_servers = {}
        local server_id = upstream_info.server_id or {}
        if server_id ~= false and #server_id > 0 then
            for k,v in pairs(server_id) do
                key = "S:"..v
                local s = cache:get(key)
                if s ~= false then
                    upstream_servers[k] = s
                end
            end
        end
        if not upstream_servers or #upstream_servers == 0 then
            return response:send(500,"no server data")
        end
        --util.wlog("ACCESS_SERVERS -> "..cjson.encode(upstream_servers))

        -- get router list by upstream
        local routers = {}
        local router_id = upstream_info.router_id or {}
        if router_id ~= false and #router_id > 0 then
            for k,v in pairs(router_id) do
                key = "R:"..v
                routers[k] = cache:get(key)
                if routers[k].server_id and #routers[k].server_id > 0 then
                    local servers = {}
                    for k1,v1 in pairs(routers[k].server_id) do
                        if type(v1) == "table" then
                            break
                        end
                        key = "S:"..v1
                        local s = cache:get(key)
                        if s ~= false then
                            servers[k1] = s
                        end
                    end
                    if #servers > 0 then
                        routers[k].server_id = servers
                    end
                end
            end
        end
        --util.wlog("ACCESS_ROUTER -> "..cjson.encode(routers))

        local balancer_address,err = router:exec(ngx,upstream_info,upstream_servers,routers)
        if not balancer_address then
            return response:send(500,"the upstream is not server")
        end

        --ctx变量传递到 balancer_by_lua_block阶段
        ctx.balancer_address = balancer_address
        var.upstream_host = upstream_info.host
        var.upstream_scheme = upstream_info.scheme

        local ok,err = router:balancer_execute(balancer_address)
end

function _M.access_after()

end


function _M.header_filter_before()

end

function _M.header_filter_after()
    ngx.header["Server"] = config.VER
end

function _M.body_filter()

end

function _M.log()

end

return _M

