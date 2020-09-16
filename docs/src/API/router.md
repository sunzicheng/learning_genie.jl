```@meta
CurrentModule = Router
```

```@docs
#### mutable struct:
Route                       (路由对象类型)
Channel                     (连接管道对象类型)
Params                      (请求体参数集合类型, 元素内类型: Dict)
#### macro:
@routes                      (获取已命名的的路由宏)
@channels                    (获取已命名的的管道宏)
#### function:
Router.show                 (打印重载函数)
ispayload                   (是否有有效请求体函数, 确定请求是否包含请求体)
route_request               (路由请求函数)
route_ws_request            (路由WebSocket请求函数)
Router.push!                (加强堆函数, map.put理解, 参数 map, k, v)
route                       (Genie route 的构造函数)
channel                     (Genie channel 的构造函数)
routename                   (推断路由的名称函数)
channelname                 (推断管道的名称函数)
baptizer                    (为路由和通道生成默认名称函数)
named_routes                (获取已命名了的路由列表)          
named_channels              (获取已命名了的管道列表)
get_route                   (获取与"routename"对应的"Route"函数)
routes                      (返回已定义路由的vector函数)
channels                    (返回已定义管道的vector函数)
delete!                     (从路由集合中删除具有相应名称的路由，并返回剩余路由的集合函数)
to_link                     (使用' route_params '中的参数生成与' route_name '对应的HTTP链接函数)
tolink                      (to_link函数别名指向, -> to_link)
link_to                     (to_link函数别名指向, -> to_link)
linkto                      (to_link函数别名指向, -> link_to -> to_link)
toroute                     (to_link函数别名指向, -> to_link)
route_params_to_dict        (将路由参数转换为“Dict”函数)
action_controller_params    (设置“params”集合的 :action_controller, :action, :controller ( key - value形式) 函数)
run_hook                    (调用指定的钩子函数)
match_routes                (将调用的URL与相应的路由进行匹配，设置执行环境并调用controller函数)
match_channels              (将调用的URL与相应的管道进行匹配，设置执行环境并调用controller函数)
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
