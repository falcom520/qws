-- Copyright (C) 2016-2017 Falcon.C [falcom520@gmail.com]
--

local mysql = require("qws.vendor.db.mysql")

local _M = {}

_M.host = "127.0.0.1"
_M.port = 3306
_M.username = nil
_M.password = nil
_M.dbname = nil
_M.charset = "utf8"

function _M:connection()

    local db = mysql.connect(self.host,self.username,self.password,self.dbname,self.charset,self.port)
    assert(db,"connect to mysql failed.")

    return db
end

function _M:init()
    --error("host->"..self.host)
    return self:connection()
end

function _M:new(option)
    self.host = option.host or self.host
    self.port = option.port or 3306
    self.username = option.username or "root"
    self.password = option.password or ""
    self.dbname = option.dbname or nil
    self.charset = option.charset or "utf8"
    return self:init()
end


return _M
