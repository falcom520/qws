# qws

QWS Web网关主要借鉴kong的整体架构和插件模式，基于openresty的各个lua-resty-xxx开发

目前支持动态负载均衡、访问定向、限速(lua-resty-limit-traffic)、请求状态统计等
