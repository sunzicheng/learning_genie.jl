```@meta
CurrentModule = Router
```

```@docs
#### mutable struct:
Route(路由对象类型)
Channel(连接管道对象类型)
Params(请求体参数集合类型, 元素内类型: Dict)
#### function:
Router.show(打印重载函数)
ispayload(是否有有效请求体函数, 确定请求是否包含请求体)
route_request(路由请求函数)
route_ws_request(路由WebSocket请求函数)
Router.push!(加强堆函数, map.put理解, 参数 map, k, v)
route(Genie route 的构造函数)
channel(Genie channel 的构造函数)
routename(推断路由的名称函数)
channelname(推断管道的名称函数)
baptizer(为路由和通道生成默认名称函数)
named_routes
routes
named_channels
channels
get_route
routes
channels
delete!
to_link
tolink
link_to
linkto
toroute
route_params_to_dict
action_controller_params
run_hook
match_routes
match_channels
parse_route
parse_channel
extract_uri_params
extract_get_params
extract_post_params
extract_request_params
content_type
content_length
request_type_is
request_type
nested_keys
setup_base_params
to_response
params
@params
_params_
request
response_type
append_to_routes_file
is_static_file(判断请求源是否为静态文件函数)
to_uri
escape_resource_path
serve_static_file
preflight_response
response_mime
file_path
filepath
pathify
file_extension
file_headers
ormatch
```
