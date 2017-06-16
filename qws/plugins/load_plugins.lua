-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--
local config = require "qws.config.config"

local _M = {}

local function load_module(module_name)
    local status,res = pcall(require,module_name)
    if status then
        return true,res
    elseif type(res) == "string" and find(res,"module '"..module_name.."' not found",nil,true) then
        return nil,res
    else
        --error(res)
        return nil,"'"..module_name.." not found."
    end
end

function _M:load_plugins()

    local sorted_plugins = {}
    for _,plugin in pairs(config.PLUGINS) do
        local ok,handler = load_module("qws.plugins."..plugin..".handler")
        if ok then
            sorted_plugins[#sorted_plugins+1] = {name = plugin,handler = handler()}
        end
    end
    return sorted_plugins
end


return _M
