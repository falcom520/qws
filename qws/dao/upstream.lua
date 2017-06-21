-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local singleton = require "qws.core.singleton"
local cache     = require "qws.dao.cache"
local flush_cache = require "qws.dao.flush_cache"
local util      = require "qws.tools.util"

local cjson = require "cjson"

local _M = {}
local time = ngx.time

-- get upstreams list
function _M:get_upstreams()

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select upstream_id,scheme,host,lb,keepalive,connect_timeout,send_timeout,read_timeout \
    from upstream where is_forbidden = 0"
    --error("dao type is ->"..type(dao))
    dao:query(sql)

    local result = dao:store_result()
    local upstream_ids = {}
    if result then
        for i,upstream_id,scheme,host,lb,keepalive,connect_timeout,send_timeout,read_timeout in result:rows() do
            local rs = {
                upstream_id     = upstream_id,
                scheme          = scheme or "http",
                host            = host,
                lb              = tonumber(lb) or 0,
                keepalive       = keepalive or 60,
                connect_timeout = connect_timeout or 60,
                send_timeout    = send_timeout or 60,
                read_timeout    = read_timeout or 60,
            }
            upstream_ids[i] = rs
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_upstreams->"..cjson.encode(upstream_ids))
    return upstream_ids
end

function _M:get_upstream_info(upstream_id)
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select upstream_id,name,scheme,host,lb,connect_timeout,send_timeout,read_timeout,is_forbidden \
    from upstream where upstream_id = "..ngx.quote_sql_str(upstream_id)
    dao:query(sql)

    local result = dao:store_result()
    local upstream = result:fetch("a")
    result:free()
    return upstream
end

function _M:get_all_upstream()
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select upstream_id,name,scheme,host,lb,connect_timeout,send_timeout,read_timeout,created_time,updated_time,is_forbidden from upstream where 1 order by created_time desc"
    dao:query(sql)

    local result = dao:store_result()
    local upstream_ids = {}
    if result then
        for i,upstream_id,name,scheme,host,lb,connect_timeout,send_timeout,read_timeout,created_time,updated_time,is_forbidden in result:rows() do
            local rs = {
                upstream_id     = upstream_id,
                name            = name,
                scheme          = scheme or "http",
                host            = host,
                lb              = tonumber(lb) or 0,
                connect_timeout = connect_timeout or 60,
                send_timeout    = send_timeout or 60,
                read_timeout    = read_timeout or 60,
                created_time     = created_time,
                updated_time    = updated_time,
                is_forbidden    = is_forbidden
            }
            upstream_ids[i] = rs
        end
    end
    result:free()
    return upstream_ids
end

-- get server by upstream_id
function _M:get_servers(upstream_id)

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,server,port,weight,fails,status \
    from upstream_server where upstream_id = '"..upstream_id.."' and is_forbidden = 0"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,server,port,weight,fails,status in result:rows() do
            local server = {
                server_id   = server_id,
                server      = server,
                port        = port,
                weight      = weight,
                fails       = fails,
                status      = tonumber(status),
            }
            res[i] = server
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_servers->"..cjson.encode(res))
    return res
end


-- get server by server_id
function _M:get_server_info(server_id)

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,server,port,weight,fails,status,is_forbidden \
    from upstream_server where server_id = "..ngx.quote_sql_str(server_id)
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,server,port,weight,fails,status,is_forbidden in result:rows() do
            local server = {
                server_id   = server_id,
                server      = server,
                port        = port,
                weight      = weight,
                fails       = fails,
                status      = tonumber(status),
                is_forbidden = tonumber(is_forbidden),
            }
            res = server
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_servers->"..cjson.encode(res))
    return res
end

function _M:get_servers_list(upstream_id)
    if not upstream_id then
        return nil,"upstream is empty"
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,server,port,weight,fails,status,created_time,updated_time,is_forbidden \
    from upstream_server where upstream_id = "..ngx.quote_sql_str(upstream_id)
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,server,port,weight,fails,status,created_time,updated_time,is_forbidden in result:rows() do
            local server = {
                server_id   = server_id,
                server      = server,
                port        = port,
                weight      = weight,
                fails       = fails,
                status      = status,
                created_time = created_time,
                updated_time = updated_time,
                is_forbidden = is_forbidden,
            }
            res[i] = server
        end
    else
        return nil,"no data"
    end
    result:free()
    return res
end


function _M:get_servers_all()
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,upstream_id,server,port,weight,fails,status from upstream_server where is_forbidden = 0"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,upstream_id,server,port,weight,fails,status in result:rows() do
            local server = {
                server_id  = server_id,
                upstream_id= upstream_id,
                server     = server,
                port       = port,
                weight     = weight,
                fails      = fails,
                status     = tonumber(status),
            }
            res[i] = server
        end
    end
    result:free()
    return res
end

function _M:get_all_servers()
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,upstream_id,server,port,weight,fails,status,is_forbidden from upstream_server where 1"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,upstream_id,server,port,weight,fails,status,is_forbidden in result:rows() do
            local server = {
                server_id  = server_id,
                upstream_id= upstream_id,
                server     = server,
                port       = port,
                weight     = weight,
                fails      = fails,
                status     = tonumber(status),
                is_forbidden = tonumber(is_forbidden),
            }
            res[i] = server
        end
    end
    result:free()
    return res
end


--get router by upstream_id
--
function _M:get_router(upstream_id)

    local dao = singleton.dao
    assert(dao,"connect to db failed.")
    local sql = "select router_id,uri,new_uri,rule,server_id \
    from router where upstream_id = '"..upstream_id.."' and is_forbidden = 0"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,router_id,uri,new_uri,rule,server_id in result:rows() do
            if rule == "" or rule == nil then
                rule = "{}"
            end
            if server_id == "" or server_id == nil then
                server_id = "{}"
            end
            local router = {
                router_id = router_id,
                uri       = uri,
                new_uri   = new_uri,
                rule      = cjson.decode(rule) or {},
                server_id = cjson.decode(server_id) or {}
            }
            res[i] = router
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_router->"..cjson.encode(res))
    return res
end


function _M:get_router_list(upstream_id)

    if not upstream_id then
        return nil,"upstream is empty"
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select router_id,server_id,rule,uri,new_uri,created_time,updated_time,is_forbidden \
    from router where upstream_id = "..ngx.quote_sql_str(upstream_id)
    dao:query(sql)

    local result = dao:store_result()
    local res = {}
    if result then
        for i,router_id,server_id,rule,uri,new_uri,created_time,updated_time,is_forbidden in result:rows() do
            local router = {
                router_id  = router_id,
                server_id  = server_id,
                rule       = rule,
                uri        = uri,
                new_uri    = new_uri,
                created_time = created_time,
                updated_time = updated_time,
                is_forbidden = is_forbidden,
            }
            res[i] = router
        end
    else
        return nil,"no data"
    end
    return res
end

function _M:get_router_info(router_id)
    if not router_id then
        return nil,"router id is empty."
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select router_id,upstream_id,server_id,rule,uri,new_uri,is_forbidden \
    from router where router_id = "..ngx.quote_sql_str(router_id)
    dao:query(sql)

    local result = dao:store_result()
    local rows = result:fetch("a")
    result:free()
    return rows
end

function _M:get_upstream_by_updatetime(time)

    local time = time or time() - 10

    local dao = singleton.dao
    assert(dao,"connect to db failed.")
    local sql = "select upstream_id,scheme,host,lb,keepalive,connect_timeout,send_timeout,read_timeout,is_forbidden \
    from upstream where updated_time >= '"..util.timetostr(time).."'"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,upstream_id,scheme,host,lb,keepalive,connect_timeout,send_timeout,read_timeout,is_forbidden in result:rows() do
            local upstream = {
                upstream_id         = upstream_id,
                scheme              = scheme,
                host                = host,
                lb                  = tonumber(lb),
                keepalive           = keepalive,
                connect_timeout     = connect_timeout,
                send_timeout        = send_timeout,
                read_timeout        = read_timeout,
                is_forbidden        = tonumber(is_forbidden),   
            }
            res[i] = upstream
        end
    else
        return nil,"no data"
    end
    result:free()
    return res
end



function _M:get_router_by_updatetime(time)

    local time = time or time() - 10
    local dao = singleton.dao
    assert(dao,"connect to db failed.")
    local sql = "select router_id,upstream_id,uri,new_uri,rule,server_id,is_forbidden \
    from router where updated_time >= '"..util.timetostr(time).."'"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,router_id,upstream_id,uri,new_uri,rule,server_id,is_forbidden in result:rows() do
            if rule == "" or rule == nil then
                rule = "{}"
            end
            if server_id == "" or server_id == nil then
                server_id = "{}"
            end
            local router = {
                router_id = router_id,
                upstream_id = upstream_id,
                uri       = uri,
                new_uri   = new_uri,
                rule      = cjson.decode(rule) or {},
                server_id = cjson.decode(server_id) or {},
                is_forbidden = tonumber(is_forbidden),
            }
            res[i] = router
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_router->"..cjson.encode(res))
    return res
end


function _M:get_server_by_updatetime(time)

    local time = time or time() - 10

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select server_id,upstream_id,server,port,weight,fails,status,is_forbidden \
    from upstream_server where updated_time >= '"..util.timetostr(time).."'"
    dao:query(sql)
    local result = dao:store_result()
    local res = {}
    if result then
        for i,server_id,upstream_id,server,port,weight,fails,status,is_forbidden in result:rows() do
            local server = {
                server_id   = server_id,
                upstream_id = upstream_id,
                server      = server,
                port        = port,
                weight      = weight,
                fails       = fails,
                status      = tonumber(status),
                is_forbidden= tonumber(is_forbidden),
            }
            res[i] = server
        end
    else
        return nil,"no data"
    end
    result:free()
    --util.wlog("get_servers->"..cjson.encode(res))
    return res
end



function _M:update_servers(server_id,data)
    
    if not server_id or not data then
        return false
    end
    if server_id == "" or type(data) ~= "table" then
        return false
    end
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    if not data["updated_time"] then
        data["updated_time"] = util.timetostr()
    end
    local set = ""
    for k,v in pairs(data) do
        if set == "" then
            set = k.." = '"..v.."'"
        else
            set = set..","..k.." = '"..v.."'"
        end
    end
    local sql = "update upstream_server set "..set.." where server_id = '"..server_id.."'"
    --util.wlog(sql)
    dao:query(sql)
    local result = dao:affected_rows()
    if result then
        return result
    end
    return 0
end


function _M:update_upstream(data)
    if not data or not data["upstream_id"] then
        return nil,"upstream_id or data is not null"
    end
    if not data["host"] then
        return nil,"host is not null"
    end
    if not util.is_empty(data['scheme']) or not util.exist_array({"http","https"},data["scheme"]) then
        data['scheme'] = 'http'
    end
    if not util.is_empty(data["connect_timeout"]) then
        data["connect_timeout"] = 60000
    elseif tonumber(data["connect_timeout"]) <= 0 or tonumber(data["connect_timeout"]) > 300000 then
        return nil,"connect_timeout range is 1ms to 300000ms"
    end
    if not util.is_empty(data["read_timeout"]) then
        data["read_timeout"] = 60000
    elseif tonumber(data["read_timeout"]) <= 0 or tonumber(data["read_timeout"]) > 300000 then
        return nil,"read_timeout range is 1ms to 300000ms"
    end
    if not util.is_empty(data["send_timeout"]) then
        data["send_timeout"] = 60000
    elseif tonumber(data["send_timeout"]) <= 0 or tonumber(data["send_timeout"]) > 300000 then
        return nil,"send_timeout range is 1ms to 300000ms"
    end
    if not util.is_empty(data['is_forbidden']) or tonumber(data['is_forbidden']) > 1 then
        data['is_forbidden'] = 1
    end
    if not data["updated_time"] then
        data["updated_time"] = util.timetostr()
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select upstream_id from upstream where host = "..ngx.quote_sql_str(data["host"])
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    result:free()

    if row and row["upstream_id"] ~= data["upstream_id"] then
        return nil,"host is exists.please use a new host."
    end

    -- upstream is or not exist
    local sql = "select upstream_id from upstream where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    result:free()
    if not row then -- add
        if not data["created_time"] then
            data["created_time"] = util.timetostr()
        end
        local field = ""
        local values = ""
        for k,v in pairs(data) do
            if field == "" then
                field = k
            else
                field = field..","..k
            end
            if values == "" then
                values = ngx.quote_sql_str(v)
            else
                values = values..","..ngx.quote_sql_str(v)
            end
        end
        local sql = "insert into upstream ("..field..") values("..values..")"
        
        dao:query(sql)
        local result = dao:affected_rows()
        if result then
            flush_cache:upstream(data["host"])
            return true
        end
        return nil,"add to db fail"
    else -- update

        local set = ""
        for k,v in pairs(data) do
            if k ~= "upstream_id" then
                if set == "" then
                    set = k.." = "..ngx.quote_sql_str(v)
                else
                    set = set.." ,"..k.." = "..ngx.quote_sql_str(v)
                end
            end
        end
        local sql = "update upstream set "..set.." where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])

        dao:query(sql)
        local result = dao:affected_rows()
        if result then
            -- if forbidden host and delete host cache
            flush_cache:upstream(data["host"])
            return true
        end
    end
    return nil,"save to db fail."

end


function _M:delete_upstream(data)
    if not data or not data["upstream_id"] then
        return nil,"upstream_id is not empty"
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select host from upstream where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    if not row then
        return nil,"the upstream_id is not exist"
    end
    result:free()

    sql = "delete from upstream where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])
    dao:query(sql)
    result = dao:affected_rows()
    if result then
        cache:del("U:"..row["host"])

        sql = "delete from upstream_server where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])
        dao:query(sql)
        result = dao:affected_rows()
        sql = "delete from router where upstream_id = "..ngx.quote_sql_str(data["upstream_id"])
        dao:query(sql)
        result = dao:affected_rows()
        --update cache info
        flush_cache:upstream(row["host"])
        return true
    end
    return nil,"delete fail."

end


function _M:update_server(data)
    if not data or not data["server_id"] then
        return nil,"server_id is not empty"
    end
    if not data["server"] then
        return nil,"server is not empty"
    end
    if not data["port"] then
        data["port"] = 80
    end
    data["is_forbidden"] = data["is_forbidden"] or 1
    if not data["updated_time"] then
        data["updated_time"] = util.timetostr()
    end

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    sql = "select server_id,upstream_id from upstream_server where server_id = "..ngx.quote_sql_str(data["server_id"])
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")

    -- check port is avaliable
    status,err = util.check_tcp(data["server"],data["port"])
    data['status'] = status
    if not row or data["server_id"] ~= row["server_id"] then --add
        if not data["created_time"] then
            data["created_time"] = util.timetostr()
        end
        local field = ""
        local value = ""
        for k,v in pairs(data) do
            if field == "" then
                field = k
            else
                field = field..","..k
            end
            if value == "" then
                value = ngx.quote_sql_str(v)
            else
                value = value..","..ngx.quote_sql_str(v)
            end
        end
        local sql = "insert into upstream_server ("..field..") values("..value..")"
        dao:query(sql)
        local result = dao:affected_rows()
        if result then
            local upstream = _M:get_upstream_info(data["upstream_id"])
            flush_cache:upstream(upstream["host"])
            return true
        end
        return nil,"add to db fail"

    else -- update

        sql = "update upstream_server set server = "..ngx.quote_sql_str(data["server"])..",port = "..ngx.quote_sql_str(data["port"])..",is_forbidden = "..ngx.quote_sql_str(data["is_forbidden"])..",status = "..ngx.quote_sql_str(data["status"]).." where server_id = "..ngx.quote_sql_str(data["server_id"])
        dao:query(sql)
        result = dao:affected_rows()
        if result then
            -- update upstream cache
            local upstream = _M:get_upstream_info(row["upstream_id"])
            flush_cache:upstream(upstream["host"])
            return true
        end
        return nil,"edit fail."
    end
    
end


function _M:delete_server(server_id)
    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select upstream_id,server_id,server from upstream_server where server_id = "..ngx.quote_sql_str(server_id)
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    if not row then
        return nil,"the server_id is not exist"
    end
    result:free()

    local sql = "select server_id from router where upstream_id = '"..row["upstream_id"].."'"
    dao:query(sql)
    local result = dao:store_result()
    local in_router = false
    for i,_server_id in result:rows() do
        if _server_id ~= "" and util.exist_array(cjson.decode(_server_id),server_id) then
            in_router = true
            break
        end
    end
    if in_router then
        return nil,"The server_id has been set in the router, and you can't delete this server_id"
    end
    
    local sql = "delete from upstream_server where server_id = "..ngx.quote_sql_str(server_id)
    dao:query(sql)
    result = dao:affected_rows()
    if result then
        local upstream = _M:get_upstream_info(row["upstream_id"])
        flush_cache:upstream(upstream["host"])
        return true
    end
    return nil,"delete fail."
end


function _M:update_router(data)
    if not data or not data["router_id"] then
        return nil,"router_id is not empty"
    end
    if not data['server_id'] then
        data['server_id'] = {}
    end
    if not data['uri'] or data['uri'] == "" then
        data['uri'] = '/'
    end
    if not data['new_uri'] or data['new_uri'] == "" then
        data['new_uri'] = '/'
    end
    if not data['server_id'] or #data['server_id'] == 0 then
        data['server_id'] = '[]'
    else
        data['server_id'] = cjson.encode(util.remove_array(cjson.decode(data['server_id']),0))
    end
    if not data['rule'] or #data['rule'] == 0 then
        data['rule'] = {}
    else
        data['rule'] = cjson.decode(data['rule'])
        local rule = {}
        local uri = {}
        local head = {}
        local i = 1
        local j = 1
        for k,v in pairs(data['rule']) do
            if v.t == "CLIENTIP" then
                rule['CLIENTIP'] = util.split(v.v,",")
            elseif v.t == 'ABTest' then
                rule['ABTest'] = v.v
            elseif v.t == 'URI' then
                local _uri_v = util.split(v.v,",")
                local _uri = {}
                _uri[v.k] = _uri_v
                uri[i] = _uri
                i = i + 1
            elseif v.t == 'HEAD' then
                local _head_v = util.split(v.v,",")
                local _head = {}
                _head[v.k] = _head_v
                head[j] = _head
                j = j+1
            end
        end
        if #uri > 0 then
            rule['URI'] = uri
        end
        if #head > 0 then
            rule['HEADERS'] = head
        end
        data['rule'] = cjson.encode(rule)
    end
    if not data['is_forbidden'] or util.exist_array({"0","1"},data['is_forbidden']) == false then
        data['is_forbidden'] = 0
    end

    local dao = singleton.dao
    assert(dao,"connect to db fail.")

    local sql = "select router_id,upstream_id from router where router_id = "..ngx.quote_sql_str(data['router_id'])
    dao:query(sql)

    local result = dao:store_result()
    local row = result:fetch('a')
    result:free()

    if not data["updated_time"] then
        data["updated_time"] = util.timetostr()
    end
    if row then -- update
        local sql = "update router set "
        for k,v in pairs(data) do
            sql = sql..k.." = "..ngx.quote_sql_str(v)..","
        end
        sql = util.trim(sql,",").." where router_id = "..ngx.quote_sql_str(data['router_id'])
        dao:query(sql)
        local result = dao:affected_rows()
        if not result then
            return nil,"the server_id is not exist"
        end
        local upstream = _M:get_upstream_info(row["upstream_id"])
        flush_cache:upstream(upstream["host"])
        return true
    else
        if not data["created_time"] then
            data["created_time"] = util.timetostr()
        end
        local sql = "insert into router ("
        local field = ""
        local value = ""
        for k,v in pairs(data) do
            if field == "" then
                field = k
            else
                field = field..","..k
            end
            if value == "" then
                value = ngx.quote_sql_str(v)
            else
                value = value..","..ngx.quote_sql_str(v)
            end
        end
        sql = sql..field..") values("..value..")"
        dao:query(sql)
        local result = dao:affected_rows()
        if not result then
            return nil,"the server_id is not exist"
        end
        local upstream = _M:get_upstream_info(data["upstream_id"])
        flush_cache:upstream(upstream["host"])
        return true
    end
end

function _M:delete_router(router_id)

    local dao = singleton.dao
    assert(dao,"connect to db failed.")

    local sql = "select router_id,upstream_id from router where router_id = "..ngx.quote_sql_str(router_id)
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    if not row then
        return nil,"the router_id is not exist"
    end
    result:free()

    sql = "delete from router where router_id = "..ngx.quote_sql_str(router_id)
    dao:query(sql)
    result = dao:affected_rows()
    if result then
        local upstream = _M:get_upstream_info(row["upstream_id"])
        flush_cache:upstream(upstream["host"])
        return true
    end
    return nil,"delete fail."

end


return _M
