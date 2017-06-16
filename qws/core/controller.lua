-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
--

local template  = require "qws.vendor.template"
local response  = require "qws.tools.response"
local util      = require "qws.tools.util"
local config    = require "qws.config.config"
local users     = require "qws.dao.user"
local cache     = require "qws.dao.cache"
local upstream  = require "qws.dao.upstream"

local cjson     = require "cjson"

local _M = {}

local req = ngx.req
local var = ngx.var
local controller,action

local sep = "/"

local router = {}

local function check_auth()
    local cookie = util.get_cookies(req.get_headers())
    if not cookie or not cookie["sid"] then
        return nil
    end
    local sid_tab = util.split(cookie["sid"],"-")
    local user = cache:get(sid_tab[1])
    if not user then
        return nil
    end
    return user
end

local function get_filename(res)
    local filename = ngx.re.match(res,'(.+)filename="(.+)"')
    if filename then
        return filename[2]
    end
end

local function get_name(res)
    local filename = ngx.re.match(res,'(.+)name="(.+)";')
    if filename then
        return filename[2]
    end
end

-- login controller
router['/_admin/login'] = function()
    local message = {message = _msg,status = status,content_type = content_type,ver = config.VER,js_ver = config.JS_VER,css_ver = config.CSS_VER}
    local view = "_admin/login/index.html"
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end

-- dashboard controller
router['/_admin/dashboard'] = function()
    local message = {
        message     = _msg,
        status      = status,
        content_type= content_type,
        ver         = config.VER,
        controller  = controller,
        action      = action,
        js_ver      = config.JS_VER,
        css_ver     = config.CSS_VER,
        user        = check_auth(),
    }
    local view = "_admin/dashboard/index.html"
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end

-- upstream controller
router['/_admin/upstream'] = function()
    local view,message
    local args = req.get_uri_args();
    local upstream_id = args["upstream_id"] or ""
    message = {
        ver = config.VER,
        controller = controller,
        action = action,
        title = "",
        js_ver = config.JS_VER,
        css_ver = config.CSS_VER,
        user = check_auth(),
    }
    if action == "" then
        view = "_admin/upstream/index.html"
    elseif action == "server" then
        message["title"] = "upstream servers"
        message["upstream_id"] = upstream_id
        view = "_admin/upstream/server/index.html"
    elseif action == "router" then
        message["title"] = "upstream routers"
        message["upstream_id"] = upstream_id
        view = "_admin/upstream/router/index.html"
    end
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end

router['/api/upstream'] = function()
    local data = {errCode = 0,errMsg = "",data = {}}
    ngx.req.read_body()
    local args,err = req.get_post_args()
    if action == "" then
        local rs = upstream:get_all_upstream()
        for k,v in pairs(rs) do
            v.lb = tonumber(v.lb)
            if v.lb == 0 then
                v.lb = "Random"
            elseif v.lb == 1 then
                v.lb = "RR"
            elseif v.lb == 2 then
                v.lb = "IP Hash"
            elseif v.lb == 3 then
                v.lb = "URL Hash"
            end
            v.created_time = string.format("%d-%d-%d %d:%d:%d",v.created_time.year,v.created_time.month,v.created_time.day,v.created_time.hour,v.created_time.min,v.created_time.sec)
            v.updated_time = string.format("%d-%d-%d %d:%d:%d",v.updated_time.year,v.updated_time.month,v.updated_time.day,v.updated_time.hour,v.updated_time.min,v.updated_time.sec)
            data["data"][k] = v
        end
    elseif action == "get" then
        if not args or not args["upstream_id"] then
            data["errCode"] = 10010
            data['errMsg'] = "upstream_id not empty."
            return response:send_json(data)
        end
        data["data"] = upstream:get_upstream_info(args['upstream_id'])
    elseif action == "edit" then
        local ok,err = upstream:update_upstream(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)
    elseif action == "add" then
        args["upstream_id"] = util.uuid()
        args['created_time'] = util.timetostr()
        local ok,err = upstream:update_upstream(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)
    elseif action == "del" then
        local ok,err = upstream:delete_upstream(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)
    end
    return response:send_json(data)
end

router['/api/upload'] = function()

    local data = {errCode = 0,errMsg = "",data = {}}
    local resty_sha1 = require "resty.sha1"
    local upload = require "resty.upload"

    local chunk_size = 4096
    local form,err = upload:new(chunk_size)
    if not form then
        data['errCode'] = 10011
        data['errMsg'] = err
        return response:send_json(data)
    end
    form:set_timeout(1000)
    local sha1 = resty_sha1:new()
    local file
    while true do
        local typ,res,err = form:read()
        if not typ then
            data["errCode"] = 10012
            data["errMsg"] = err
            return response:send_json(data)
        end
        if typ == "header" then
            util.wlog(cjson.encode(res[2]))
            local file_name = get_filename(res[2])
            local name = get_name(res[2])
            if file_name then
                util.wlog(file_name.."->"..name)
                file = io.open(config.SSL_DIR.."/"..name..string.sub(file_name,-4),"w+")
                if not file then
                    data["errCode"] = 10013
                    data["errMsg"] = "failed to open file "..file_name
                    return response:send_json(data)
                end
            end
        elseif typ == "body" then
            if file then
                file:write(res)
                sha1:update(res)
            end
        elseif typ == "part_end" then
            if file then
                file:close()
                file = nil
            end
            local sha1_sum = sha1:final()
            sha1:reset()
        elseif typ == "eof" then
            break
        end
    end
    return response:send_json(data)
end

router['/api/servers'] = function()
    local data = {errCode = 0,errMsg = "",data = {}}
    ngx.req.read_body()
    local args,err = req.get_post_args()
    if action == "" then
        if not args or not args["upstream_id"] then
            data.errCode = 10010
            data.errMsg = "upstream_id is not empty"
            return response:send_json(data)
        end
        local upstream_info = upstream:get_upstream_info(args["upstream_id"])
        if not upstream_info then
            data.errCode = 10011
            data.errMsg = "upstream info is not empty"
            return response:send_json(data)
        end
        local servers,err = upstream:get_servers_list(args["upstream_id"])
        if not servers then
            data.errCode = 10012
            data.errMsg = err
            return response:send_json(data)
        end
        for i,v in pairs(servers) do
            v.created_time = string.format("%d-%d-%d %d:%d:%d",v.created_time.year,v.created_time.month,v.created_time.day,v.created_time.hour,v.created_time.min,v.created_time.sec)
            v.updated_time = string.format("%d-%d-%d %d:%d:%d",v.updated_time.year,v.updated_time.month,v.updated_time.day,v.updated_time.hour,v.updated_time.min,v.updated_time.sec)
            servers[i] = v
        end
        data.data["upstream"] = {upstream_id = upstream_info.upstream_id,host = upstream_info.host,name = upstream_info.name}
        data.data["servers"] = servers
        return response:send_json(data)
    elseif action == "get" then
        if not args or not args["server_id"] then
            data.errCode = 10010
            data.errMsg = "server_id is not empty"
            return response:send_json(data)
        end
        local server_info,err = upstream:get_server_info(args["server_id"])
        if not server_info then
            data.errCode = 10010
            data.errMsg = "server_id is not empty"
            return response:send_json(data)
        end
        data.data = server_info
        return response:send_json(data)
    elseif action == "add" then
        args["server_id"] = util.uuid()
        local ok,err = upstream:update_server(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)   
    elseif action == "edit" then
        local ok,err = upstream:update_server(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)   
    elseif action == "del" then
        if not args or not args["server_id"] then
            data.errCode = 10010
            data.errMsg = "server_id is not empty"
            return response:send_json(data)
        end
        local ok,err = upstream:delete_server(args["server_id"])
        if not ok then
            data.errCode = 100101
            data.errMsg = err
            return response:send_json(data)
        end
        return response:send_json(data)
    end
end


router['/api/router'] = function()
    local data = {errCode = 0,errMsg = "",data = {}}
    ngx.req.read_body()
    local args,err = req.get_post_args()
    if action == "" then
        if not args or not args["upstream_id"] then
            data.errCode = 10010
            data.errMsg = "upstream_id is not empty"
            return response:send_json(data)
        end
        local upstream_info = upstream:get_upstream_info(args["upstream_id"])
        if not upstream_info then
            data.errCode = 10011
            data.errMsg = "upstream info is not empty"
            return response:send_json(data)
        end
        local routers,err = upstream:get_router_list(args["upstream_id"])
        if not routers then
            data.errCode = 10012
            data.errMsg = err
            return response:send_json(data)
        end
        for i,v in pairs(routers) do
            v.created_time = string.format("%d-%d-%d %d:%d:%d",v.created_time.year,v.created_time.month,v.created_time.day,v.created_time.hour,v.created_time.min,v.created_time.sec)
            v.updated_time = string.format("%d-%d-%d %d:%d:%d",v.updated_time.year,v.updated_time.month,v.updated_time.day,v.updated_time.hour,v.updated_time.min,v.updated_time.sec)
            if v.server_id ~= "" then
                v.server_id = cjson.decode(v.server_id)
                for ii,vv in pairs(v.server_id) do
                    local server_info = upstream:get_server_info(vv)
                    v.server_id[ii] = server_info.server..":"..server_info.port
                end
            end
            if v.rule ~= "" then
                v.rule = cjson.decode(v.rule)
            end
            routers[i] = v
        end
        data.data["upstream"] = {upstream_id = upstream_info.upstream_id,host = upstream_info.host,name = upstream_info.name}
        data.data["routers"] = routers
        return response:send_json(data)
    elseif action == "get" then
        if not args or not args["router_id"] then
            data.errCode = 10010
            data.errMsg = "router_id is not empty"
            return response:send_json(data)
        end
        local router_info,err = upstream:get_router_info(args["router_id"])
        if not router_info then
            data.errCode = 10010
            data.errMsg = "router_id is not empty"
            return response:send_json(data)
        end
        router_info.server_list = upstream:get_servers(router_info.upstream_id)
        if router_info.server_id ~= "" then
            router_info.server_id = cjson.decode(router_info.server_id)
        end
        if router_info.rule ~= "" then
            router_info.rule = cjson.decode(router_info.rule)
        end
        data.data = router_info
        return response:send_json(data)
    elseif action == "get_server" then
        if not args and not args['upstream_id'] then
            data.errCode = 10010
            data.errMsg = "router_id is not empty"
            return response:send_json(data)
        end
        local server_list = upstream:get_servers(args["upstream_id"])
        if not server_list then
            server_list = {}
        end
        local servers = {}
        for k,v in pairs(server_list) do
            local row = {
                server = v.server..":"..v.port,
                server_id = v.server_id
            }
            servers[k] = row
        end
        data.data = servers
        return response:send_json(data)
    elseif action == "add" then
        args["router_id"] = util.uuid()
        local ok,err = upstream:update_router(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)   
    elseif action == "edit" then
        local ok,err = upstream:update_router(args)
        if not ok then
            data["errCode"] = 10010
            data["errMsg"] = err
            return response:send_json(data)
        end
        return response:send_json(data)   
    elseif action == "del" then
        if not args or not args["router_id"] then
            data.errCode = 10010
            data.errMsg = "router_id is not empty"
            return response:send_json(data)
        end
        local ok,err = upstream:delete_router(args["router_id"])
        if not ok then
            data.errCode = 100101
            data.errMsg = err
            return response:send_json(data)
        end
        return response:send_json(data)
    end
end

---- api controller

-- traffic controller
router['/_admin/traffic'] = function()
    local message = {message = _msg,status = status,content_type = content_type,ver = config.VER}
    local view = "_admin/traffic/index.html"
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end


-- log controller
router['/_admin/log'] = function()
    local message = {message = _msg,status = status,content_type = content_type,ver = config.VER}
    local view = "_admin/log/index.html"
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end


-- firewall controller
router['/_admin/firewall'] = function()
    local message = {message = _msg,status = status,content_type = content_type,ver = config.VER}
    local view = "_admin/firewall/index.html"
    var.template_root = config.TEMPLATE_ROOT
    template.render(view,message)
end

router['/api/logout'] = function()
    local cookie = util.get_cookies(req.get_headers())
    if not cookie or not cookie["sid"] then
        return ngx.redirect("/_admin/login")
    end
    local sid_tab = util.split(cookie["sid"],"-")
    local user = cache:get(sid_tab[1])
    if user then
        local access_times_key = "_ADMIN:"..user.user
        cache:del(access_times_key)
    end
    local expires = ngx.cookie_time(ngx.time() - 3600)
    ngx.header["Set-Cookie"] = {'sid='..sid_tab[1]..'-'..user.user_id..';expires='..expires..';path=/'}
    cache:del(sid_tab[1])
    return ngx.redirect("/_admin/login")
end

---- api controller

router['/api/login'] = function()
    ngx.req.read_body()
    local args,err = req.get_post_args()
    local username = args["email"] or nil
    local password = args["password"] or nil
    local remember = tonumber(args["remember"]) or 0


    local data = {}
    if not username or username == "" or not password or password == "" then
        data = {errCode = 10010,errMsg = "user or password is not empty.",data = {}}
        return response:send_json(data)
    end

    -- check access fails
    local access_times_key = "_ADMIN:"..username
    local times,err = cache:s_get(access_times_key)
    if times  and tonumber(times) >= 10 then
        return response:send(403)
    end

    local user = nil
    md5_password = ngx.md5(password)
    --util.wlog(" ->"..password.."   "..md5_password)
    for k,v in pairs(users) do
        if username == v.user and md5_password == v.password then
            user = v
            break
        end
    end


    if user then
        data = {errCode = 0,errMsg = "login success."}
        local sid = ngx.md5(user.user.."_SID:"..user.user_id)
        local expires = ngx.cookie_time(ngx.time()+3600*6)
        local time = 3600*6
        if remember == 0 then
            expires = 0
            time = 3600*2
        else
            expires = ngx.cookie_time(ngx.time() + 24*3600*7)
            time = 24*3600*7
        end
        ngx.header["Set-Cookie"] = {'sid='..sid..'-'..user.user_id..';path=/;expires='..expires}
        cache:set(sid,user,time)
        return response:send_json(data)
    else
        data = {errCode = 10000 ,errMsg = "user login failed."}
        local times,err = cache:s_get(access_times_key)
        if not times then
            cache:s_set(access_times_key,1,3600)
        else
            cache:incr(access_times_key,1)
        end
        return response:send_json(data)
    end
end


function _M:run()
    local path = var.uri
    local c_arr = util.split(util.trim(path,"/"),sep)
    --util.wlog(cjson.encode(c_arr).." -> "..path)
    if #c_arr == 3 then
        controller = "/"..c_arr[1].."/"..c_arr[2]
        action = c_arr[3]
    elseif #c_arr == 2 then
        controller = "/"..c_arr[1].."/"..c_arr[2]
        action = ""
    elseif #c_arr == 1 then
        controller = "/"..c_arr[1].."/dashboard"
        action = ""
    else
        controller = "/_admin/dashboard"
        action = ""
    end
    local method = req.get_method()
    local allow_method = {"GET","POST"}
    if not util.exist_array(allow_method,method) then
        return response:send(405,method.." not allowed.")
    end
    if not router[controller] then
        return response:send(404,controller.." Not Found")
    end

    if method == "GET" then
        local user = check_auth()
        if controller == "/_admin/login" then
           if user then
               return ngx.redirect("/_admin/dashboard",302)
           else
               return router[controller]()
           end
        end
        if not user and controller ~= "/_admin/login" then
            return ngx.redirect("/_admin/login",302)
        end

        return router[controller]()
    else
        if controller == "/api/login" then
            return router[controller]()
        end
        local cookie = util.get_cookies(req.get_headers())
        if not cookie or not cookie["sid"] then
            local data = {errCode = 10000,errMsg = "not login",data = {}}
            return response:send_json(data)
        end
        return router[controller]()
    end
end

return _M

