"""
Parses requests and extracts parameters, setting up the call variables and invoking
解析请求和提取参数，设置调用变量和调用

the appropiate route handler function.
适当的 route处理函数。
"""
module Router

import Revise
# Reexport 用法: 导出 已导入的包到 （把引入包导出， 达到单一导入多个包目的）  
import Reexport, Logging
# OrderedCollections 有序集合（java -> TreeMap, 有序Set）;
# URIParser 资源解析器
import HTTP, URIParser, HttpCommon, Sockets, Millboard, Dates, OrderedCollections, JSON
import Genie

# 服务器请求头相关常量包
include("mimetypes.jl")

export route, routes, channel, channels, serve_static_file
export GET, POST, PUT, PATCH, DELETE, OPTIONS
export tolink, linkto, responsetype, toroute
export @params, @routes, @channels

Reexport.@reexport using HttpCommon

const GET     = "GET"
const POST    = "POST"
const PUT     = "PUT"
const PATCH   = "PATCH"
const DELETE  = "DELETE"
const OPTIONS = "OPTIONS"

const BEFORE_HOOK  = :before
const AFTER_HOOK   = :after

const request_mappings = Dict{Symbol,String}(
  :text       => "text/plain",
  :html       => "text/html",
  :json       => "application/json",
  :javascript => "application/javascript",
  :form       => "application/x-www-form-urlencoded",
  :multipart  => "multipart/form-data",
  :file       => "application/octet-stream",
  :xml        => "text/xml"
)

#=
    钩子函数集合
=#
# 匹配前钩子函数集合
const pre_match_hooks = Function[]
# 响应前钩子函数集合
const pre_response_hooks = Function[]
# 内容协议钩子函数集合
const content_negotiation_hooks = Function[]


"""
    mutable struct Route

Representation of a route object
路由的表示形式 
"""
mutable struct Route
  method::String
  path::String
  action::Function
  name::Union{Symbol,Nothing}
end

# 空参处理
Route(; method = GET, path = "", action = (() -> error("Route not set")), name = nothing) = Route(method, path, action, name)


"""
    mutable struct Channel

Representation of a WebSocket Channel object
WebSocket通道对象的表示形式
"""
mutable struct Channel
  path::String
  action::Function
  name::Union{Symbol,Nothing}

  # 管道空处理
  Channel(; path = "", action = (() -> error("Channel not set")), name = nothing) =
    new(path, action)
end

# 增强原有的show方法
function Base.show(io::IO, r::Route)
  print(io, "[$(r.method)] $(r.path) => $(r.action) | :$(r.name)")
end
function Base.show(io::IO, c::Channel)
  print(io, "[WS] $(c.path) => $(c.action) | :$(c.name)")
end

# 存储容器
const _routes = OrderedCollections.OrderedDict{Symbol,Route}()
const _channels = OrderedCollections.OrderedDict{Symbol,Channel}()


"""
    mutable struct Params{T}

Collection of key value pairs representing the parameters of the current request - response cycle.
表示当前请求-响应周期的参数的键值对的集合。
"""
mutable struct Params{T}
  collection::Dict{Symbol,T}
end
#=
    默认构造函数：
        方法体： 
            参数构造函数：
                参数： 从配置环境中获取构造参数 -> setup_base_params()
=#
Params() = Params(setup_base_params())

# 增强原有方法
Base.Dict(params::Params) = params.collection

Base.getindex(params, keys...) = getindex(Dict(params), keys...)


"""
    _params_()

Reference to the request variables collection.
请求变量集合的引用
"""
function _params_()
  # 本地存储（?，未明白意思）
  task_local_storage(:__params)
end
function _params_(key::Union{String,Symbol})
  task_local_storage(:__params)[key]
end


"""
    ispayload(req::HTTP.Request)

True if the request can carry a payload - that is, it's a `POST`, `PUT`, or `PATCH` request
如果请求可以携带有效负载——即“POST”、“PUT”或“PATCH”请求，则为True
"""
ispayload(req::HTTP.Request) = req.method in [POST, PUT, PATCH]


"""
    # 路由请求: (request, response, ip) -> response
    route_request(req::Request, res::Response, ip::IPv4 = Genie.config.server_host) :: Response

First step in handling a request: sets up @params collection, handles query vars, negotiates content.
处理请求的第一步:设置@params集合，处理查询变量，协商内容。
"""
function route_request(req::HTTP.Request, res::HTTP.Response, ip::Sockets.IPv4 = Sockets.IPv4(Genie.config.server_host)) :: HTTP.Response
  # 构造请求体对象
  params = Params()
  # 设置请求ip, 形式 key -> value
  params.collection[:request_ipv4] = ip

  # 运行内容协议钩子函数
  for f in unique(content_negotiation_hooks)
    # 执行函数
    req, res, params.collection = f(req, res, params.collection)
  end

  if is_static_file(req.target)
    # 是静态文件, 判断是否运行提供静态文件
    Genie.config.server_handle_static_files && return serve_static_file(req.target)

    return error(req.target, response_mime(), Val(404))
  end

  # 如果为测试环境，手动刷新(如同JReble，重新构建一个意思)
  Genie.Configuration.isdev() && Revise.revise()

  # 运行匹配前钩子函数
  for f in unique(pre_match_hooks)
    req, res, params.collection = f(req, res, params.collection)
  end

  # 将调用的URL与相应的路由进行匹配，设置执行环境并调用controller方法。
  res = match_routes(req, res, params)

  # 如果为 404（true）->请求方式为 OPTIONS(握手认证) -> 忽略错误，返回握手成功
  res.status == 404 && req.method == OPTIONS && return preflight_response()

  # 执行响应前钩子函数
  for f in unique(pre_response_hooks)
    req, res, params.collection = f(req, res, params.collection)
  end

  # 拼接结果打印
  reqstatus = "$(req.target) $(res.status)\n"

  # 日志记录
  if res.status < 400
    @info reqstatus
  else
    @error reqstatus
  end

  res
end


"""
    route_ws_request(req::Request, msg::String, ws_client::HTTP.WebSockets.WebSocket, ip::IPv4 = Genie.config.server_host) :: String

First step in handling a web socket request: sets up @params collection, handles query vars.
处理web套接字请求的第一步:设置@params集合，处理查询变量。
"""
function route_ws_request(req, msg::String, ws_client, ip::Sockets.IPv4 = Sockets.IPv4(Genie.config.server_host)) :: String
  params = Params()

  # ws => WebSocket
  params.collection[Genie.PARAMS_WS_CLIENT] = ws_client

  # 执行并得到参数
  extract_get_params(URIParser.URI(req.target), params)

  # 如果为测试环境，手动刷新(如同JReble，重新构建一个意思)
  Genie.Configuration.isdev() && Revise.revise()

  # 执行请求前钩子函数
  for f in unique(pre_match_hooks)
    req, msg, params.collection = f(req, msg, params.collection)
  end

  # 找到相应管道，设置好环境并执行管道控制器的方法
  match_channels(req, msg, ws_client, params)
end

# 增强原有添加方法
function Base.push!(collection, name::Symbol, item::Union{Route,Channel})
  collection[name] = item
end


"""
Named Genie routes constructors.
名为 Genie routes 构造函数
"""
function route(action::Function, path::String; method = GET, named::Union{Symbol,Nothing} = nothing) :: Route
  route(path, action, method = method, named = named)
end
function route(path::String, action::Function; method = GET, named::Union{Symbol,Nothing} = nothing) :: Route
  r = Route(method = method, path = path, action = action, name = named)

  if named === nothing
    r.name = routename(r)
  end

  Router.push!(_routes, r.name, r)
end


"""
Named Genie channels constructors.
名为 Genie channels 构造函数
"""
function channel(action::Function, path::String; named::Union{Symbol,Nothing} = nothing) :: Channel
  channel(path, action, named = named)
end
function channel(path::String, action::Function; named::Union{Symbol,Nothing} = nothing) :: Channel
  c = Channel(path = path, action = action, name = named)

  if named === nothing
    c.name = channelname(c)
  end

  Router.push!(_channels, c.name, c)
end


"""
    routename(params) :: Symbol

Computes the name of a route.
推断路由的名称。
"""
function routename(params::Route) :: Symbol
  baptizer(params, String[lowercase(params.method)])
end


"""
    channelname(params) :: Symbol

Computes the name of a channel.
推断管道的名称。
"""
function channelname(params::Channel) :: Symbol
  baptizer(params, String[])
end


"""
    baptizer(params::Union{Route,Channel}, parts::Vector{String}) :: Symbol

Generates default names for routes and channels.
为路由和通道生成默认名称。
"""
function baptizer(params::Union{Route,Channel}, parts::Vector{String}) :: Symbol
  for uri_part in split(params.path, "/", keepempty = false)
    startswith(uri_part, ":") && continue # we ignore named params
    push!(parts, lowercase(uri_part))
  end

  join(parts, "_") |> Symbol
end


"""
The list of the defined named routes.
已定义的命名路由的列表。
"""
function named_routes() :: OrderedCollections.OrderedDict{Symbol,Route}
  _routes
end
const namedroutes = named_routes


"""
    @routes

Collection of named routes
获取已命名的的路由宏
"""
macro routes()
  _routes
end


"""
    named_channels() :: Dict{Symbol,Any}

The list of the defined named channels.
获取已命名了的管道列表
"""
function named_channels() :: OrderedCollections.OrderedDict{Symbol,Channel}
  _channels
end
const namedchannels = named_channels


"""
    @channels

Collection of named channels.
获取已命名的的管道宏
"""
macro channels()
  _channels
end


"""
Gets the `Route` correspoding to `routename`
获取与"routename"对应的"Route"函数
"""
function get_route(route_name::Symbol; default::Union{Route,Nothing} = Route()) :: Route
  haskey(named_routes(), route_name) ?
    named_routes()[route_name] :
    (if default === nothing
      Base.error("Route named `$route_name` is not defined")
    else
      @warn "Route named `$route_name` is not defined"
      default
    end)
end


"""
    routes() :: Vector{Route}

Returns a vector of defined routes.
返回已定义路由的vector函数。
注: reverse 反转
"""
function routes() :: Vector{Route}
  collect(values(_routes)) |> reverse
end


"""
    channels() :: Vector{Channel}

Returns a vector of defined channels.
返回已定义管道的vector函数。
注: reverse 反转
"""
function channels() :: Vector{Channel}
  collect(values(_channels)) |> reverse
end


"""
    delete!(routes, route_name::Symbol)

Removes the route with the corresponding name from the routes collection and returns the collection of remaining routes.
从路由集合中删除具有相应名称的路由，并返回剩余路由的集合函数。
"""
function delete!(routes::OrderedCollections.OrderedDict{Symbol,Route}, key::Symbol) :: OrderedCollections.OrderedDict{Symbol,Route}
  OrderedCollections.delete!(routes, key)
end


"""
Generates the HTTP link corresponding to `route_name` using the parameters in `d`.
使用' d '中的参数生成与' route_name '对应的HTTP链接函数。
"""
function to_link(route_name::Symbol, d::Dict{Symbol,T}; preserve_query::Bool = true, extra_query::Dict = Dict())::String where {T}
  route = get_route(route_name)

  result = String[]
  for part in split(route.path, "/")
    if occursin("#", part)
      part = split(part, "#")[1]
    end

    if startswith(part, ":")
      var_name = split(part, "::")[1][2:end] |> Symbol
      ( isempty(d) || ! haskey(d, var_name) ) && error("Route $route_name expects param $var_name")
      push!(result, pathify(d[var_name]))
      Base.delete!(d, var_name)
      continue
    end

    push!(result, part)
  end

  query_vars = Dict{String,String}()
  if preserve_query && haskey(task_local_storage(), :__params) && haskey(task_local_storage(:__params), :REQUEST)
    query = URIParser.URI(task_local_storage(:__params)[:REQUEST].target).query
    if ! isempty(query)
      for pair in split(query, '&')
        try
          parts = split(pair, '=')
          query_vars[parts[1]] = parts[2]
        catch ex
          # @error ex
        end
      end
    end
  end

  for (k,v) in extra_query
    query_vars[string(k)] = string(v)
  end

  qv = String[]
  for (k,v) in query_vars
    push!(qv, "$k=$v")
  end

  join(result, "/") * ( ! isempty(qv) ? "?" : "" ) * join(qv, "&")
end


"""
Generates the HTTP link corresponding to `route_name` using the parameters in `route_params`.
使用' route_params '中的参数生成与' route_name '对应的HTTP链接函数。
"""
function to_link(route_name::Symbol; preserve_query::Bool = true, extra_query::Dict = Dict(), route_params...) :: String
  to_link(route_name, route_params_to_dict(route_params), preserve_query = preserve_query, extra_query = extra_query)
end

# 多种命名指向指向同一函数索引, 解决相识命名问题
const link_to = to_link
const linkto = link_to
const tolink = to_link
const toroute = to_link


"""
    route_params_to_dict(route_params)

Converts the route params to a `Dict`.
将路由参数转换为“Dict”函数
"""
function route_params_to_dict(route_params) :: Dict{Symbol,Any}
  Dict{Symbol,Any}(route_params)
end


"""
    action_controller_params(action::Function, params::Params) :: Nothing

Sets up the :action_controller, :action, and :controller key - value pairs of the `params` collection.
设置“params”集合的 :action_controller, :action, :controller ( key - value形式)
"""
function action_controller_params(action::Function, params::Params) :: Nothing
  params.collection[:action_controller] = action |> string |> Symbol
  params.collection[:action] = nameof(action)
  params.collection[:controller] = (action |> typeof).name.module |> string |> Symbol

  nothing
end


"""
    run_hook(controller::Module, hook_type::Symbol) :: Bool

Invokes the designated hook.
调用指定的钩子函数
"""
function run_hook(controller::Module, hook_type::Symbol) :: Bool
  isdefined(controller, hook_type) || return false

  getfield(controller, hook_type) |> Base.invokelatest

  true
end


"""
    match_routes(req::Request, res::Response, params::Params) :: Response

Matches the invoked URL to the corresponding route, sets up the execution environment and invokes the controller method.
将调用的URL与相应的路由进行匹配，设置执行环境并调用controller方法。
"""
function match_routes(req::HTTP.Request, res::HTTP.Response, params::Params) :: HTTP.Response
  for r in routes()
    r.method != req.method && continue

    parsed_route, param_names, param_types = parse_route(r.path)

    uri = URIParser.URI(to_uri(req.target))
    regex_route = try
      Regex("^" * parsed_route * "\$")
    catch
      @error "Invalid route $parsed_route"

      continue
    end

    occursin(regex_route, uri.path) || parsed_route == "/*" || continue

    params.collection = setup_base_params(req, res, params.collection)
    task_local_storage(:__params, params.collection)

    occursin("?", req.target) && extract_get_params(URIParser.URI(to_uri(req.target)), params)

    extract_uri_params(uri.path, regex_route, param_names, param_types, params) || continue

    ispayload(req) && extract_post_params(req, params)
    ispayload(req) && extract_request_params(req, params)
    action_controller_params(r.action, params)

    for f in unique(content_negotiation_hooks)
      req, res, params.collection = f(req, res, params.collection)
    end

    params.collection[Genie.PARAMS_ROUTE_KEY] = r

    get!(params.collection, Genie.PARAMS_MIME_KEY, MIME(request_type(req)))

    controller = (r.action |> typeof).name.module

    return  try
              run_hook(controller, BEFORE_HOOK)

              result = try
                (r.action)() |> to_response
              catch
                Base.invokelatest(r.action) |> to_response
              end

              run_hook(controller, AFTER_HOOK)

              result

            catch ex
              if isa(ex, Genie.Exceptions.ExceptionalResponse)
                return ex.response
              elseif isa(ex, Genie.Exceptions.RuntimeException)
                rethrow(ex)
              elseif isa(ex, Genie.Exceptions.InternalServerException)
                return error(ex.message, response_mime(), Val(500))
              elseif isa(ex, Genie.Exceptions.NotFoundException)
                return error(ex.resource, response_mime(), Val(404))
              elseif isa(ex, Exception)
                rethrow(ex)
              end
            end
  end

  error(req.target, response_mime(params.collection), Val(404))
end


"""
    match_channels(req::Request, msg::String, ws_client::HTTP.WebSockets.WebSocket, params::Params) :: String

Matches the invoked URL to the corresponding channel, sets up the execution environment and invokes the channel controller method.
将调用的URL匹配到相应的通道，设置执行环境并调用通道控制器方法。
"""
function match_channels(req, msg::String, ws_client, params::Params) :: String
  for c in channels()
    parsed_channel, param_names, param_types = parse_channel(c.path)

    payload::Dict{String,Any} = try
                                  JSON.parse(msg)
                                catch ex
                                  Dict{String,Any}()
                                end

    uri = haskey(payload, "channel") ? "/" * payload["channel"] : "/"
    uri = haskey(payload, "message") ? uri * "/" * payload["message"] : uri

    haskey(payload, "payload") && (params.collection[:payload] = payload["payload"])

    regex_channel = Regex("^" * parsed_channel * "\$")

    (! occursin(regex_channel, uri)) && continue

    params.collection = setup_base_params(req, nothing, params.collection)
    task_local_storage(:__params, params.collection)

    extract_uri_params(uri, regex_channel, param_names, param_types, params) || continue

    action_controller_params(c.action, params)

    params.collection[Genie.PARAMS_CHANNELS_KEY] = c

    controller = (c.action |> typeof).name.module

    return  try
                run_hook(controller, BEFORE_HOOK)

                result = try
                  (c.action)() |> string
                catch
                  Base.invokelatest(c.action) |> string
                end

                run_hook(controller, AFTER_HOOK)

                result
              catch ex
                isa(ex, Exception) ? sprint(showerror, ex) : rethrow(ex)
              end
  end

  string("ERROR : 404 - Not found")
end


"""
    parse_route(route::String) :: Tuple{String,Vector{String},Vector{Any}}

Parses a route and extracts its named params and types.
"""
function parse_route(route::String) :: Tuple{String,Vector{String},Vector{Any}}
  parts = String[]
  param_names = String[]
  param_types = Any[]

  if occursin('#', route) || occursin(':', route)
    validation_match = "[\\w\\-\\.\\+\\,\\s\\%]+"

    for rp in split(route, "/", keepempty = false)
      if occursin("#", rp)
        x = split(rp, "#")
        rp = x[1]
        validation_match = x[2]
      end

      if startswith(rp, ":")
        param_type =  if occursin("::", rp)
                        x = split(rp, "::")
                        rp = x[1]
                        getfield(@__MODULE__, Symbol(x[2]))
                      else
                        Any
                      end
        param_name = rp[2:end]

        rp = """(?P<$param_name>$validation_match)"""

        push!(param_names, param_name)
        push!(param_types, param_type)
      end

      push!(parts, rp)
    end
  else
    parts = split(route, "/", keepempty = false)
  end

  "/" * join(parts, "/"), param_names, param_types
end


"""
    parse_channel(channel::String) :: Tuple{String,Vector{String},Vector{Any}}

Parses a channel and extracts its named parms and types.
解析通道并提取其命名的parms和类型。
"""
function parse_channel(channel::String) :: Tuple{String,Vector{String},Vector{Any}}
  parts = String[]
  param_names = String[]
  param_types = Any[]

  if occursin(':', channel)
    for rp in split(channel, "/", keepempty = false)
      if startswith(rp, ":")
        param_type =  if occursin("::", rp)
                        x = split(rp, "::")
                        rp = x[1]
                        getfield(@__MODULE__, Symbol(x[2]))
                      else
                        Any
                      end
        param_name = rp[2:end]
        rp = """(?P<$param_name>[\\w\\-]+)"""
        push!(param_names, param_name)
        push!(param_types, param_type)
      end
      push!(parts, rp)
    end
  else
    parts = split(channel, "/", keepempty = false)
  end

  "/" * join(parts, "/"), param_names, param_types
end


"""
    extract_uri_params(uri::String, regex_route::Regex, param_names::Vector{String}, param_types::Vector{Any}, params::Params) :: Bool

Extracts params from request URI and sets up the `params` `Dict`.
"""
function extract_uri_params(uri::String, regex_route::Regex, param_names::Vector{String}, param_types::Vector{Any}, params::Params) :: Bool
  matches = match(regex_route, uri)

  i = 1
  for param_name in param_names
    try
      params.collection[Symbol(param_name)] = convert(param_types[i], matches[param_name])
    catch ex
      @error "Failed to match URI params between $(param_types[i])::$(typeof(param_types[i])) and $(matches[param_name])::$(typeof(matches[param_name]))"
      @error ex

      return false
    end

    i += 1
  end

  true # this must be bool cause it's used in bool context for chaining
end


"""
    extract_get_params(uri::URI, params::Params) :: Bool

Extracts query vars and adds them to the execution `params` `Dict`.
提取查询变量并将其添加到执行 “params” “Dict” 中。
"""
function extract_get_params(uri::URIParser.URI, params::Params) :: Bool
  # GET params
  if ! isempty(uri.query)
    for query_part in split(uri.query, "&")
      qp = split(query_part, "=")
      (size(qp)[1] == 1) && (push!(qp, ""))

      k = Symbol(URIParser.unescape(qp[1]))
      v = URIParser.unescape(qp[2])
      params.collection[k] = params.collection[Genie.PARAMS_GET_KEY][k] = v
    end
  end

  true # this must be bool cause it's used in bool context for chaining
end


"""
    extract_post_params(req::Request, params::Params) :: Nothing

Parses POST variables and adds the to the `params` `Dict`.
"""
function extract_post_params(req::HTTP.Request, params::Params) :: Nothing
  ispayload(req) || return nothing

  input = Genie.Input.all(req)

  for (k, v) in input.post
    nested_keys(k, v, params)

    k = Symbol(k)
    params.collection[k] = params.collection[Genie.PARAMS_POST_KEY][k] = v
  end

  params.collection[Genie.PARAMS_FILES] = input.files

  nothing
end


"""
    extract_request_params(req::HTTP.Request, params::Params) :: Nothing

Sets up the `params` key-value pairs corresponding to a JSON payload.
"""
function extract_request_params(req::HTTP.Request, params::Params) :: Nothing
  ispayload(req) || return nothing

  params.collection[Genie.PARAMS_RAW_PAYLOAD] = String(req.body)

  if request_type_is(req, :json) && content_length(req) > 0
    try
      params.collection[Genie.PARAMS_JSON_PAYLOAD] = JSON.parse(params.collection[Genie.PARAMS_RAW_PAYLOAD])
    catch ex
      @error sprint(showerror, ex)
      @warn "Setting @params(:JSON_PAYLOAD) to Nothing"

      params.collection[Genie.PARAMS_JSON_PAYLOAD] = nothing
    end
  else
    params.collection[Genie.PARAMS_JSON_PAYLOAD] = nothing
  end

  nothing
end


"""
    content_type(req::HTTP.Request) :: String

Gets the content-type of the request.
"""
function content_type(req::HTTP.Request) :: String
  get(Genie.HTTPUtils.Dict(req), "content-type", get(Genie.HTTPUtils.Dict(req), "accept", ""))
end


"""
    content_length(req::HTTP.Request) :: Int

Gets the content-length of the request.
"""
function content_length(req::HTTP.Request) :: Int
  parse(Int, get(Genie.HTTPUtils.Dict(req), "content-length", "0"))
end
function content_length() :: Int
  content_length(_params_(Genie.PARAMS_REQUEST_KEY))
end


"""
    request_type_is(req::HTTP.Request, request_type::Symbol) :: Bool

Checks if the request content-type is of a certain type.
"""
function request_type_is(req::HTTP.Request, request_type::Symbol) :: Bool
  ! in(request_type, keys(request_mappings) |> collect) && error("Unknown request type $request_type - expected one of $(keys(request_mappings) |> collect).")

  occursin(request_mappings[request_type], content_type(req)) && return true

  false
end
function request_type_is(request_type::Symbol) :: Bool
  request_type_is(_params_(Genie.PARAMS_REQUEST_KEY), request_type)
end


"""
    request_type(req::HTTP.Request) :: Symbol

Gets the request's content type.
"""
function request_type(req::HTTP.Request) :: Symbol
  accepted_encodings = split(content_type(req), ',')

  for accepted_encoding in accepted_encodings
    for (k,v) in request_mappings
      if occursin(v, accepted_encoding)
        return k
      end
    end
  end

  Symbol(accepted_encodings[1])
end


"""
    nested_keys(k::String, v, params::Params) :: Nothing

Utility function to process nested keys and set them up in `params`.
"""
function nested_keys(k::String, v, params::Params) :: Nothing
  if occursin(".", k)
    parts = split(k, ".", limit = 2)
    nested_val_key = Symbol(parts[1])

    if haskey(params.collection, nested_val_key) && isa(params.collection[nested_val_key], Dict)
      ! haskey(params.collection[nested_val_key], Symbol(parts[2])) && (params.collection[nested_val_key][Symbol(parts[2])] = v)
    elseif ! haskey(params.collection, nested_val_key)
      params.collection[nested_val_key] = Dict()
      params.collection[nested_val_key][Symbol(parts[2])] = v
    end
  end

  nothing
end


"""
    setup_base_params(req::Request, res::Response, params::Dict{Symbol,Any}) :: Dict{Symbol,Any}

Populates `params` with default environment vars.
使用默认环境变量填充“参数”。
"""
function setup_base_params(req::HTTP.Request = HTTP.Request(), res::Union{HTTP.Response,Nothing} = req.response,
                            params::Dict{Symbol,Any} = Dict{Symbol,Any}()) :: Dict{Symbol,Any}
  params[Genie.PARAMS_REQUEST_KEY]   = req
  params[Genie.PARAMS_RESPONSE_KEY]  = res
  params[Genie.PARAMS_POST_KEY]      = Dict{Symbol,Any}()
  params[Genie.PARAMS_GET_KEY]       = Dict{Symbol,Any}()

  params[Genie.PARAMS_FILES]         = Dict{String,Genie.Input.HttpFile}()

  params
end


"""
    to_response(action_result) :: Response

Converts the result of invoking the controller action to a `Response`.
"""
to_response(action_result::HTTP.Response)::HTTP.Response = action_result
to_response(action_result::Tuple)::HTTP.Response = HTTP.Response(action_result...)
to_response(action_result::Vector)::HTTP.Response = HTTP.Response(join(action_result))
to_response(action_result::Nothing)::HTTP.Response = HTTP.Response("")
to_response(action_result::String)::HTTP.Response = HTTP.Response(action_result)
to_response(action_result::Genie.Exceptions.ExceptionalResponse)::HTTP.Response = action_result.response
to_response(action_result::Exception)::HTTP.Response = throw(action_result)
to_response(action_result::Any)::HTTP.Response = HTTP.Response(string(action_result))


"""
    @params

The object containing the request variables collection.
"""
macro params()
  quote
    task_local_storage(:__params)
  end
end
macro params(key)
  :((@params)[$key])
end
macro params(key, default)
  quote
    haskey(@params, $key) ? @params($key) : $default
  end
end


"""
    @request()

The request object.
"""
macro request()
  :(_params_(Genie.PARAMS_REQUEST_KEY))
end


"""
    response_type{T}(params::Dict{Symbol,T}) :: Symbol
    response_type(params::Params) :: Symbol

Returns the content-type of the current request-response cycle.
"""
function response_type(params::Dict{Symbol,T})::Symbol where {T}
  get(params, :response_type, request_type(params[Genie.PARAMS_REQUEST_KEY]))
end
function response_type(params::Params) :: Symbol
  response_type(params.collection)
end
function response_type() :: Symbol
  response_type(@params())
end


"""
    response_type{T}(check::Symbol, params::Dict{Symbol,T}) :: Bool

Checks if the content-type of the current request-response cycle matches `check`.
"""
function response_type(check::Symbol, params::Dict{Symbol,T})::Bool where {T}
  check == response_type(params)
end


const responsetype = response_type


"""
    append_to_routes_file(content::String) :: Nothing

Appends `content` to the app's route file.
"""
function append_to_routes_file(content::String) :: Nothing
  open(Genie.ROUTES_FILE_NAME, "a") do io
    write(io, "\n" * content)
  end

  nothing
end


"""
    # 是否为静态文件
    is_static_file(resource::String) :: Bool

Checks if the requested resource is a static file.
检查请求资源是否为静态文件
"""
function is_static_file(resource::String) :: Bool
  isfile(file_path(to_uri(resource).path))
end


"""
    to_uri(resource::String) :: URI

Attempts to convert `resource` to URI
"""
function to_uri(resource::String) :: URIParser.URI
  try
    URIParser.URI(resource)
  catch ex
    qp = URIParser.query_params(resource) |> keys |> collect
    escaped_resource = join(map( x -> ( startswith(x, "/") ? escape_resource_path(string(x)) : URIParser.escape(string(x)) ) * "=" * URIParser.escape(URIParser.query_params(resource)[string(x)]), qp ), "&")

    URIParser.URI(escaped_resource)
  end
end


"""
    escape_resource_path(resource::String)

Cleans up paths to resources.
"""
function escape_resource_path(resource::String)
  startswith(resource, "/") || return resource
  resource = resource[2:end]

  "/" * join(map(x -> URIParser.escape(x), split(resource, "?")), "?")
end


"""
    serve_static_file(resource::String) :: Response

Reads the static file and returns the content as a `Response`.
"""
function serve_static_file(resource::String; root = Genie.config.server_document_root) :: HTTP.Response
  startswith(resource, "/") || (resource = "/$resource")
  resource_path = try
                    URIParser.URI(resource).path
                  catch ex
                    resource
                  end
  f = file_path(resource_path, root = root)

  if isfile(f)
    return HTTP.Response(200, file_headers(f), body = read(f, String))
  elseif isdir(f)
    isfile(joinpath(f, "index.html")) && return serve_static_file(joinpath(f, "index.html"), root = root)
    isfile(joinpath(f, "index.htm")) && return serve_static_file(joinpath(f, "index.htm"), root = root)
  else
    bundled_path = joinpath(@__DIR__, "..", "files", "static", resource[2:end])
    if isfile(bundled_path)
      return HTTP.Response(200, file_headers(bundled_path), body = read(bundled_path, String))
    end
  end

  @error "404 Not Found $f"
  error(resource, response_mime(), Val(404))
end


"""
preflight_response() :: HTTP.Response

Sets up the preflight CORS response header.
设置返回前response的CORS响应头。
"""
function preflight_response() :: HTTP.Response
  HTTP.Response(200, Genie.config.cors_headers, body = "Success")
end


"""
    response_mime()

Returns the MIME type of the response.
"""
function response_mime(params::Dict{Symbol,Any} = _params_())
  rm = get!(params, Genie.PARAMS_MIME_KEY, request_type(params[Genie.PARAMS_REQUEST_KEY]))

  if isempty(string(rm()))
    params[Genie.PARAMS_MIME_KEY] = request_type(params[Genie.PARAMS_REQUEST_KEY])
  end

  params[Genie.PARAMS_MIME_KEY]
end


"""
    error

Not implemented function for error response.
"""
function error end


function error(error_message::String, mime::Any, ::Val{500}; error_info::String = "") :: HTTP.Response
  HTTP.Response(500, ["Content-Type" => string(mime())], body = "500 Internal Error - $error_message. $error_info")
end


function error(error_message::String, mime::Any, ::Val{404}; error_info::String = "") :: HTTP.Response
  HTTP.Response(404, ["Content-Type" => string(mime())], body = "404 Not Found - $error_message. $error_info")
end


function error(error_code::Int, error_message::String, mime::Any; error_info::String = "") :: HTTP.Response
  HTTP.Response(error_code, ["Content-Type" => string(mime())], body = "$error_code Error - $error_message. $error_info")
end


"""
    file_path(resource::String; within_doc_root = true) :: String

Returns the path to a resource file. If `within_doc_root` it will automatically prepend the document root to `resource`.
"""
function file_path(resource::String; within_doc_root = true, root = Genie.config.server_document_root) :: String
  within_doc_root = within_doc_root && root == Genie.config.server_document_root
  joinpath(within_doc_root ? Genie.config.server_document_root : root, resource[(startswith(resource, "/") ? 2 : 1):end])
end
const filepath = file_path


"""
    pathify(x) :: String

Returns a proper URI path from a string `x`.
"""
pathify(x) :: String = replace(string(x), " "=>"-") |> lowercase |> URIParser.escape


"""
    file_extension(f) :: String

Returns the file extesion of `f`.
"""
file_extension(f) :: String = ormatch(match(r"(?<=\.)[^\.\\/]*$", f), "")


"""
    file_headers(f) :: Dict{String,String}

Returns the file headers of `f`.
"""
function file_headers(f) :: Vector{Pair{String,String}}
  ["Content-Type" => get(mimetypes, file_extension(f), "application/octet-stream")]
end


ormatch(r::RegexMatch, x) = r.match
ormatch(r::Nothing, x) = x

end
