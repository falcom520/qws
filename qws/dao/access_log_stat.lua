-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local singleton = require "qws.core.singleton"
local util      = require "qws.tools.util"
local _M = {}


function _M:update(data)
    if not data then
        return nil,""
    end

    local dao = singleton.dao
    
    local where = ""
    local set = ""
    local field = ""
    local values = ""
    for k,v in pairs(data) do
        if k == "request_num" then
            set = "request_num = "..v
        else
            if where == "" then
                where = k.." = '"..v.."'"
            else
                where = where.." and "..k.." = '"..v.."'"
            end
        end

        if field == "" then
            field = k
        else
            field = field..","..k
        end

        if values == "" then
            values = "'"..v.."'"
        else
            values = values..",'"..v.."'"
        end
    end
    local sql = "select count(1) as num from `access.log.stat` where "..where
    dao:query(sql)
    local result = dao:store_result()
    local row = result:fetch("a")
    result:free()

    if not row or row["num"] == 0 then -- add
        sql = "insert into `access.log.stat` ("..field..") values("..values..")"
    else -- update
        sql = "update `access.log.stat` set "..set.." where "..where
    end
    dao:query(sql)
    local result = dao:affected_rows()
    if result then
        return true
    end
    return false
end


function _M:get_host_stat()
    local stime = tonumber(util.timetostr(util.time(),"%Y%m01"))
    local etime = tonumber(util.timetostr(util.time(),"%Y%m"..os.time({year=os.date("%Y"),month=os.date("%m")+1,day=0})))
    local sql = "select a.upstream_id,u.name,a.time,sum(a.request_num) as num from `access.log.stat` as a LEFT JOIN upstream as u on a.upstream_id = u.upstream_id where a.time >="..stime.." and a.time <= "..etime.." GROUP BY a.upstream_id,a.time"
    local dao = singleton.dao
    dao:query(sql)

    local host_stat = {}
    local result = dao:store_result()
    if result then
        for i,upstream_id,name,time,num in result:rows() do
            local row = {
                upstream_id = upstream_id,
                name        = name,
                time        = time,
                num         = tonumber(num),
            }
            host_stat[i] = row
        end
    end
    return host_stat
end


function _M:get_backend_stat(upstream_id)

    local stime = tonumber(util.timetostr(util.time(),"%Y%m01"))
    local etime = tonumber(util.timetostr(util.time(),"%Y%m"..os.time({year=os.date("%Y"),month=os.date("%m")+1,day=0})))
    local sql
    if not upstream_id or upstream_id == "" then
        sql = "SELECT backend,time,sum(request_num) AS num FROM `access.log.stat`WHERE time >= "..stime.." AND time <= "..etime.." GROUP BY backend,time"
    else
        sql = "SELECT backend,time,sum(request_num) AS num FROM `access.log.stat`WHERE upstream_id = '"..upstream_id.."' and time >= "..stime.." AND time <= "..etime.." GROUP BY backend,time"
    end
    local dao = singleton.dao
    dao:query(sql)

    local backend_stat = {}
    local result = dao:store_result()
    if result then
        for i,backend,time,num in result:rows() do
            local row = {
                backend = backend,
                time        = time,
                num         = num,
            }
            backend_stat[i] = row
        end
        result:free()
    end
    return backend_stat
end


function _M:get_status_stat(upstream_id)
    local dao = singleton.dao
    local stime = tonumber(util.timetostr(util.time(),"%Y%m01"))
    local etime = tonumber(util.timetostr(util.time(),"%Y%m"..os.time({year=os.date("%Y"),month=os.date("%m")+1,day=0})))
    local sql
    if not upstream_id or upstream_id == "" then
        sql = "select time,backend,status,sum(request_num) as num from `access.log.stat` where time >= "..stime.." and time <= "..etime.." group by time,status"
    else
        sql = "select time,backend,status,sum(request_num) as num from `access.log.stat` where upstream_id = '"..upstream_id.."' and time >= "..stime.." and time <= "..etime.." group by time,status"
    end
    dao:query(sql)

    local data = {}
    local field = {}
    local result = dao:store_result()
    for i,time,backend,status,num in result:rows() do
        local key = backend.."["..status.."]"
        data[i] = {time = time,num = num,item = key}
        if util.exist_array(field,key) == false then
            field[#field+1] = key
        end
    end
    result:free()
    return data,field
end


function _M:get_stat_list()

    local date = util.timetostr(util.time(),"%Y%m%d")
    local dao = singleton.dao
    local sql = "select status,sum(request_num) as num from `access.log.stat` where time = "..date.." group by status"
    dao:query(sql)

    local data = {}
    local result = dao:store_result()
    local _status = {}
    for k,status,num in result:rows() do
        local row = {
            status = status,
            num    = num,
        }
        _status["s"..status] = row
    end
    data.status = _status
    result:free()

    sql = "select sum(request_num) as request from `access.log.stat` where time ="..date
    dao:query(sql)
    result = dao:store_result()
    local row = result:fetch("a")
    data.request = row["request"]

    return data
end

function _M:get_list(upstream_id,stime,etime)
    
    local dao = singleton.dao

    local where = "1"
    if upstream_id ~= "" then
       where = where.." and upstream_id = '"..upstream_id.."' " 
    end
    if stime then
        where = where.." and time >= "..stime
    end
    if etime then
        where = where.." and time <= "..etime
    end
    local sql = "select upstream_id,backend,uri,method,status,sum(request_num) as num from `access.log.stat` where "..where.." group by backend,uri,method,status"
    dao:query(sql)

    local data = {}
    local result = dao:store_result()
    for k,upstream_id,backend,uri,method,status,request_num,time in result:rows() do
        local row = {
            upstream_id = upstream_id,
            backend  = backend,
            uri      = uri,
            method   = method,
            status   = status,
            request_num = request_num,
            time     = time,
        }
        data[k] = row
    end
    return data
end

return _M
