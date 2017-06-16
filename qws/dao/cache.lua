-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--
local msgpack= require "qws.vendor.MessagePack"

local cache  = ngx.shared.UPSTREAM

local _M = {}


function _M:set(key,val,exptime)
    if not key or key == "" then
        return false
    end
    if not val then
        return false
    end
    local exptime = exptime or 0
    local ok,err = cache:safe_set(key,msgpack.pack(val),exptime)
    if ok then
        return ok
    end
    return false
end

function _M:get(key)
    if not key then
        return false
    end
    local value,flag = cache:get(key)
    if value then
        return msgpack.unpack(value)
    end
    return false
end

function _M:del(key)
    if not key then
        return false
    end
    return cache:delete(key)
end

function _M:get_keys()
    return cache:get_keys()
end

function _M:safe_add(key,value,expire)
    return cache:safe_add(key,value,expire)
end

function _M:s_set(key,value,expire)
    return cache:set(key,value,expire)
end
function _M:s_get(key)
    return cache:get(key)
end

function _M:lpush(key,val)
    if not key or key == "" then
        return false
    end
    if not val then
        return false
    end
    local len,err = cache:lpush(key,msgpack.pack(val))
    if not len then
        return false
    end
    return len
end

function _M:rpop(key)
    local val,err = cache:rpop(key)
    if not val then
        return false
    end
    return msgpack.unpack(val)
end

function _M:llen(key)
    local llen,err = cache:llen(key)
    if not llen then
        return 0
    end
    return llen
end

function _M:incr(key,value,init)
    if not init then
        return cache:incr(key,value)
    else
        return cache:incr(key,value,init)
    end
end

return _M
