-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local resolver   = require "resty.dns.resolver"
local response   = require "qws.tools.response"
local util       = require "qws.tools.util"
local cjson      = require "cjson"


local var = ngx.var
local req = ngx.req
local math = math
local counter = ngx.shared.counter

local _M = {}

local function matching(routers)

    local uri           = var.uri
    local new_uri       = nil
    local rules         = nil
    local server_id     = nil
    local exclude_servers = nil --exclude server_id array
    local remote_addr   = var.remote_addr
    local headers       = req.get_headers()

    if routers and #routers > 0 then
        local k,router
        for k,router in ipairs(routers) do
            -- uri match
            if not new_uri and not server_id then
                if uri == router.uri and router.new_uri ~= "/" then
                    if util.substr(router.uri,-1) == '/' and uri ~= '/' then
                        new_uri = router.new_uri
                    else
                        new_uri = router.new_uri..uri
                    end
                elseif util.substr(uri,1,#router.uri) == router.uri then
                    if router.uri ~= '/' and util.substr(router.uri,-1) == '/' then
                        new_uri = router.new_uri..util.substr(uri,#router.uri)
                    elseif router.new_uri ~= '/' then
                        new_uri = router.new_uri..uri
                    else
                        new_uri = uri
                    end
                elseif router.uri == uri.."/" then
                    new_uri = router.new_uri.."/"
                elseif router.uri == router.new_uri and uri == "/" then
                    rules = router.rule
                    server_id = router.server_id
                end
                -- get router rule
                if new_uri then
                    rules = router.rule
                    server_id = router.server_id
                end
                if server_id then
                    exclude_servers = {}
                    for s1,v1 in pairs(server_id) do
                        exclude_servers[#exclude_servers+1] = v1.server_id
                    end
                end

                local match_all_num = 0 -- contain URI,HEADERS,CLIENTIP,SERVERID all match
                local match_all_i = 0
                if rules then
                    local k,rule
                    for k,rule in pairs(rules) do
                        match_all_num = match_all_num + 1
                        local method = string.lower(req.get_method())
                        local match_num = #rule
                        local match_i = 0
                        if method == "get" and k == 'URI' then -- match uri params
                            local args = req.get_uri_args()
                            for k,v in pairs(rule) do
                                for k1,v1 in pairs(v) do
                                    if type(v1) == "table" and util.exist_array(v1,args[k1]) then
                                        --util.wlog(cjson.encode(v1))
                                        match_i = match_i + 1
                                    elseif args[k1] == tostring(v1) then
                                        match_i = match_i + 1
                                    end
                                end
                            end
                            if match_num == match_i then
                                match_all_i = match_all_i + 1
                            end
                        elseif k == 'CLIENTIP' then -- match client ip
                            if util.is_array(rule) then
                                for k,v in pairs(rule) do
                                    local ip,err = util.check_ipv4(v)
                                    local net,mask = util.is_net(v)
                                    if ip and remote_addr == v then
                                        match_all_i = match_all_i + 1
                                    elseif net and mask and util.exist_net(v,remote_addr) then
                                        match_all_i = match_all_i + 1
                                    end
                                end
                            end
                            --util.wlog("CLIENTIP->"..cjson.encode(rule).." ip->"..remote_addr)
                        elseif k == 'HEADERS' then -- match custom header
                            for k,v in pairs(rule) do
                                for k1,v1 in pairs(v) do
                                    if type(v1) == "table" and util.exist_array(v1,headers[k1]) then
                                        match_i = match_i + 1
                                    elseif headers[k1] == tostring(v1) then
                                        match_i = match_i + 1
                                    end
                                end
                            end
                        elseif k == 'ABTest' then -- match abtest rate
                            local factor = 1
                            if tonumber(rule) % 1 < 1 and tonumber(rule) < 1 then
                                local rate_arr = util.split(rule,".")
                                factor = 10^#rate_arr[2] 
                            else
                                factor = 1
                            end
                            local crc32 = util.ip2number(remote_addr) % factor
                            if tonumber(crc32) <= tonumber(rule*factor) then
                                match_all_i = match_all_i + 1
                                exclude_servers = server_id
                            end
                        end
                    end
                end
                --util.wlog(" match_all_num -> "..match_all_num.." ------------------- match_all_i->"..match_all_i)
                if match_all_num ~= match_all_i then
                    new_uri = nil
                    server_id = nil
                end

            else
                break
            end
        end
    end

    if new_uri and new_uri ~= '/' then
        var.upstream_uri = new_uri
    end

    if server_id then
        return server_id,exclude_servers
    end

    return nil,exclude_servers,"no assign server_id"
end

function _M:exec(ngx,upstream,upstream_servers,routers)

    local uri = var.uri
    local new_uri = nil
    local balancer_address

    local server_id,exclude_servers,err = matching(routers)
    --util.wlog("MATCHING ROUTERS ->"..cjson.encode(upstream_servers).." exclude_servers->"..cjson.encode(exclude_servers))

    local servers = nil
    if not server_id or #server_id == 0 then
        if exclude_servers then
            servers = {}
            for k,v in pairs(upstream_servers) do
                if util.exist_array(exclude_servers,v["server_id"]) == false then
                    servers[#servers+1] = v
                end
            end
        else
            servers = upstream_servers
        end
    else
        servers = server_id
    end

    --util.wlog("SERVERS LIST->"..cjson.encode(servers).."            ---------> lb "..upstream.lb)

    -- loadbalancer calc 0为RR,1为轮询,2为ip_hash,3为url_hash
    local server = nil
    local sid = 1
    local lb = upstream.lb
    if lb == 1 then -- 轮询
        local access_counter,err,forcible = counter:incr(upstream.host,1,0)
        if not access_counter then
            access_counter = 1
        end
        sid = (access_counter % #servers)+1
    elseif lb == 2 then -- ip_hash
        local crc = util.ip2number(var.remote_addr)
        sid = (crc % #servers)+1
    elseif lb == 3 then -- url_hash
        local crc = ngx.crc32_long(uri)
        sid = (crc % #servers)+1
    else -- RR
        sid = (os.time() % #servers)+1
    end
    server = servers[sid]

    --util.wlog("SERVERS LIST->servers:"..cjson.encode(servers).." server->"..cjson.encode(server).."            ---------> lb ->"..lb.."    sid->"..sid)

    if not server then
        return nil,"no server"
    end

    balancer_address = {
        server_type    = util.hostname_type(server.server),
        server         = server.server,
        ip             = server.server,
        port           = server.port,
        tries          = 0,
        retries        = 3,
        connect_timeout = upstream.connect_timeout,
        send_timeout    = upstream.send_timeout,
        read_timeout    = upstream.read_timeout,

    }
    return balancer_address
end

--balancer execute
function _M:balancer_execute(addr)
    if addr.server_type ~= "name" then
        addr.ip     = addr.server
        addr.server = addr.server..":"..addr.port
        return true
    end
    --resolver domain to ip
    local ip,err = util.dns_query(addr.server)
    if not ip then
        return nil,err
    end
    addr.ip = ip
    return true
end


return _M
