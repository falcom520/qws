-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--

local ffi       = require "ffi"
local bit       = require "bit"
local uuid      = require "qws.tools.uuid"
local config    = require "qws.config.config"
local cache     = require "qws.dao.cache"

local cjson     = require "cjson"

local C             = ffi.C
local ffi_new       = ffi.new
local ffi_str       = ffi.string
local type          = type
local pairs         = pairs
local ipairs        = ipairs
local sort          = table.sort
local concat        = table.concat
local insert        = table.insert
local lower         = string.lower
local fmt           = string.format
local find          = string.find
local gsub          = string.gsub
local re_find       = ngx.re.find
local re_match      = ngx.re.match
local time          = ngx.time
local substr        = string.sub


ffi.cdef[[
typedef unsigned char u_char;

int gethostname(char *name,size_t len);

int RAND_bytes(u_char *buf,int num);

unsigned long ERR_get_error(void);
void ERR_load_crypto_strings(void);
void ERR_free_strings(void);

const char *ERR_reason_error_string(unsigned long e);

unsigned long inet_addr(const char *cp);
]]

local _M = {}

_M.pack = function(...) return {n = select("#",...),...} end

_M.unpack = function(t,i,j) return unpack(t,i or 1,j or t.n or #t) end

_M.substr = function(str,offset,len) return substr(str,offset,len) end

function _M.split(s, delim,callback)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end
    local start = 1
    local t = {}
    while true do
        local pos = string.find (s, delim, start, true) -- plain find
        if not pos then
            break
        end
        if not callback then
            table.insert (t, string.sub (s, start, pos - 1))
        else
            table.insert (t, callback(string.sub (s, start, pos - 1)))
        end
        start = pos + string.len (delim)
    end
    if not callback then
        table.insert (t, string.sub (s, start))
    else
        table.insert (t, callback(string.sub (s, start)))
    end
    return t
end

function _M.trim(s,delim)
    if not delim then
        return (gsub(s, "^%s*(.-)%s*$", "%1"))
    end
    return (gsub(s, "^"..delim.."*(.-)"..delim.."*$", "%1"))
end

function _M.time()
    local zone = tonumber(os.date("%z", 0))/100
    if zone == 8 then
        return time()
    elseif zone > 8 then
        return os.time()-(zone-8)*3600
    elseif zone < 8 then
        return os.time()+(8 - zone)*3600
    end
end

function _M.timetostr(time,format)
    local format = format or "%Y-%m-%d %H:%M:%S"
    local time = tonumber(time) or _M.time()
    return os.date(format,time)
end

function _M.get_hostname()
    local result
    local SIZE = 128

    local buf = ffi_new("unsigned char[?]",SIZE)
    local res = C.gethostname(buf,SIZE)

    if res == 0 then
        local hostname = ffi_str(buf,SIZE)
        result = gsub(hostname,"%z+$","")
    else
        local f = io.open("/bin/hostname")
        local hostname = f:read("*a") or ""
        f:close()
        result = gsub(hostname,"\n$","")
    end

    return result
end

function _M.uuid() 
    return uuid.generate()
end

function _M.is_valid_uuid(str)
    if type(str) ~= 'string' or #str ~= 36 then return false end
    local uuid_regex = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    return re_find(str,uuid_regex,'ioj') ~= nil
end

--check server host type, ipv4 ipv6 name
function _M.hostname_type(name)
    local str,nums = gsub(name,":","")
    if nums > 1 then return "ipv6" end
    if str:match("^[%d%.]+$") then return "ipv4" end
    return "name"
end

--check ipv4
function _M.check_ipv4(address)
    local a,b,c,d,port
    if address:find(":") then
        a,b,c,d,port = address:match("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?):(%d+)$")
    else
        a,b,c,d,port = address:match("^(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)%.(%d%d?%d?)$")
    end
    if not a then
        return nil,"invalid ipv4 address:"..address
    end
    a,b,c,d = tonumber(a),tonumber(b),tonumber(c),tonumber(d)
    if (a < 0 ) or ( a > 255 ) or ( b < 0) or (c <0) or (c>255) or (d<0) or (d>255) then
        return nil,"invalid ipv4 address:"..address
    end
    if port then
        port = tonumber(port)
        if port > 65535 then
            return nil,"invalid port number"
        end
    end

    return fmt("%d.%d.%d.%d",a,b,c,d),port
end

--check ipv6
function _M.check_ipv6(address)
    local check,port = address:match("^(%b[])(.-)$")
    if port == "" then port = nil end
    if check then
        check = check:sub(2,-2)
        if port then
            port = port:match("^:(%d-)$")
            if not port then
                return nil,"invalid ipv6 address"
            end
            port = tonumber(port)
            if port > 65535 then
                return nil,"invalid port number"
            end
        end
    else
        check = address
        port = nil
    end
    
    if check:sub(1,1) == ":" then check = "0"..check end
    if check:sub(-1,-1) == ":" then check = check.."0" end
    if check:find("::") then
        local _,count = gsub(check,":","")
        local ins = ":"..string.rep("0:",8-count)
        check = gsub(check,"::",ins,1)
    end

    local a,b,c,d,e,f,g,h = check:match("^(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?):(%x%x?%x?%x?)$")
    if not a then
        -- not a valid IPv6 address
        return nil, "invalid ipv6 address: "..address
    end
    local zeros = "0000"
    return lower(fmt("%s:%s:%s:%s:%s:%s:%s:%s",
        zeros:sub(1,4 - #a)..a,
        zeros:sub(1,4 - #b)..b,
        zeros:sub(1,4 - #c)..c,
        zeros:sub(1,4 - #d)..d,
        zeros:sub(1,4 - #e)..e,
        zeros:sub(1,4 - #f)..f,
        zeros:sub(1,4 - #g)..g,
        zeros:sub(1,4 - #h)..h)),port
end


--check hostname
function _M.check_hostname(address)
    local name = address
    local port = address:match(":(%d+)$")
    if port then
        name = name:sub(1,-(#port+2))
        port = tonumber(port)
        if port > 65535 then
            return nil,"invalid port number"
        end
    end
    local match = name:match("^[%d%a%-%.%_]+$")
    if match == nil then
        return nil,"invalid hostname:"..address
    end
    for _, segment in ipairs(split(name, ".")) do
        if segment == "" or segment:match("-$") or segment:match("^%.") or segment:match("%.$") then
            return nil, "invalid hostname: "..address
        end
    end
    return name,port
end


function _M.ip2number(ipv4)
    local addr = _M.split(ipv4,".")
    if not addr or #addr ~= 4 then
        return nil
    end
    local i = 0
    i = i + bit.lshift(addr[1],24)
    i = i + bit.lshift(addr[2],16)
    i = i + bit.lshift(addr[3],8)
    i = i + addr[4]
    return i
end

-- is or not network segment
function _M.is_net(cidr)
    local addr = _M.split(cidr,"/")
    if not addr or #addr ~= 2 then
        return false
    end
    if tonumber(addr[2]) > 32 then
        return false
    end
    local ip,port = _M.check_ipv4(addr[1])
    if not ip then
        return false
    end
    return addr[1],addr[2]
end

-- is or not 
function _M.exist_net(cidr,ip)
    local net,mask = _M.is_net(cidr)
    if not net then
        return false
    end
    return bit.band(_M.ip2number(ip),bit.bnot(bit.lshift(1,32 - mask)-1)) == _M.ip2number(net)
end

--record log file , append mode
function _M.wlog(string)
    local file = assert(io.open(config.SYS_LOG,"a+"),"log file is not exists.")
    string = _M.timetostr(_M.time()).." "..string.."\n"
    file:write(string)
    file:close()
end

function _M.is_array(t)
    if type(t) ~= "table" then return false end
    local i = 0
    for _ in pairs(t) do
        i = i+1
        if t[i] == nil and t[tostring(i)] == nil then return false end
    end
    return true
end

function _M.exist_array(arr,val)
    if arr then
        for _,v in pairs(arr) do
            if tostring(v) == tostring(val) then
                return true
            end
        end
    end
    return false
end

function _M.remove_array(arr,val)
    if _M.exist_array(arr,val) then
        local new_arr = {}
        local i = 1
        for _,v in pairs(arr) do
            if tostring(v) ~= tostring(val) then
                new_arr[i] = v
                i = i+1
            end
        end
        return new_arr
    end
    return arr
end

function _M.is_empty(s)
    if not s or s == "" then
        return nil
    end
    return true
end

function _M.dns_query(host)
    if _M.hostname_type(host) ~= "name" then
        return host
    end
    local k = "DOMAIN:"..host
    local ip,err = cache:s_get(k)
    if not ip  then
        local resolver = require "resty.dns.resolver"
        local r,err = resolver:new(config.DNS_SERVERS)
        if not r then
            return nil,err
        end
        local answers, err = r:query(host)
        if not answers then
            return nil,err
        end
        if answers.errcode then
            return nil,answners.errcode
        end
        local ip = nil
        for i,ans in ipairs(answers) do
            if ans.address and not ip then
                ip = ans.address
                break
            end
        end
        cache:s_set(k,ip,1800)
        return ip
    end
    return ip
end


function _M.get_cookies(headers)
    if not headers or not headers["Cookie"] then
        return nil
    end
    local cookies = {}
    local cookie = _M.split(headers["Cookie"],";")
    for i,v in pairs(cookie) do
        local c = _M.split(v,"=")
        cookies[_M.trim(c[1])] = c[2]
    end
    return cookies
end

function _M.check_tcp(ip,port)
    local ip,err = _M.dns_query(ip)
    if not ip then
        return 2,err
    end
    local ip = ip or nil 
    local port = port or nil
    if not ip or not port then
        return 2,""
    end
    local tcp = ngx.socket.tcp
    local sock = tcp()
    sock:settimeout(2000)
    local ok,err = sock:connect(ip,port)
    if not ok then
        return 2,err
    end
    sock:setkeepalive()
    return 0
end


return _M
