"""
Core genie configuration / settings functionality.
核心精灵配置/设置功能。
"""
module Configuration

using Revise

"""
  const GENIE_VERSION

References the current Genie version number.
引用当前的Genie版本号。
"""
const GENIE_VERSION = v"1.1"

import Logging
import Genie
# 加密相关包
import MbedTLS

export isdev, isprod, istest, env
export Settings, DEV, PROD, TEST

# app environments
const DEV   = "dev"
const PROD  = "prod"
const TEST  = "test"

# 不存在时 设置环境默认值
haskey(ENV, "GENIE_ENV") || (ENV["GENIE_ENV"] = DEV)
haskey(ENV, "HOST") || (ENV["HOST"] = "127.0.0.1")


"""
    isdev()  :: Bool

Set of utility functions that return whether or not the current environment is development, production or testing.
一组实用函数，返回当前环境是开发、生产还是测试。
# Examples
```julia
julia> Configuration.isdev()
true

julia> Configuration.isprod()
false
```
"""
isdev() :: Bool  = (Genie.config.app_env == DEV)


"""
    isprod() :: Bool

Set of utility functions that return whether or not the current environment is development, production or testing.
一组实用函数，返回当前环境是开发、生产还是测试。
# Examples
```julia
julia> Configuration.isdev()
true

julia> Configuration.isprod()
false
```
"""
isprod():: Bool = (Genie.config.app_env == PROD)


"""
    istest() :: Bool

Set of utility functions that return whether or not the current environment is development, production or testing.
一组实用函数，返回当前环境是开发、生产还是测试。

# Examples
```julia
julia> Configuration.isdev()
true

julia> Configuration.isprod()
false
```
"""
istest():: Bool = (Genie.config.app_env == TEST)


"""
    env() :: String

Returns the current Genie environment.
返回当前的精灵环境。
# Examples
```julia
julia> Configuration.env()
"dev"
```
"""
env() :: String = Genie.config.app_env


"""
    buildpath() :: String

Constructs the temp dir where Genie's view files are built.
构造构建精灵视图文件的temp目录。
"""
buildpath() :: String = Base.Filesystem.mktempdir(prefix = "jl_genie_build_", cleanup = false)


"""
    mutable struct Settings

App configuration - sets up the app's defaults. Individual options are overwritten in the corresponding environment file.
应用程序配置-设置应用程序的默认设置。在相应的环境文件中覆盖各个选项。

# Arguments
- `server_port::Int`: the port for running the web server (default 8000)
                      用于运行web服务器的端口(默认为8000)
- `server_host::String`: the host for running the web server (default "127.0.0.1")
                         运行web服务器的主机(默认为“127.0.0.1”)
- `server_document_root::String`: path to the document root (default "public/")
                                  文档根目录的路径(默认为“public/”)
- `server_handle_static_files::Bool`: if `true`, Genie will also serve static files. In production, it is recommended to serve static files with a web server like Nginx.
                                      如果“true”，Genie还将提供静态文件。在生产中，建议使用像Nginx这样的web服务器来提供静态文件。
- `server_signature::String`: Genie's signature used for tagging the HTTP responses. If empty, it will not be added.
                              Genie用于标记HTTP响应的签名。如果为空，则不会添加。
- `app_env::String`: the environment in which the app is running (dev, test, or prod)
                     应用程序运行的环境(dev、test或prod)
- `cors_headers::Dict{String,String}`: default `Access-Control-*` CORS settings
                                       默认的“Access-Control-*” CORS设置
- `cors_allowed_origins::Vector{String}`: allowed origin hosts for CORS settings
                                          允许原点主机进行CORS设置
- `cache_duraction::Int`: cache expiration time in seconds
                          缓存过期时间(秒)
- `log_level::Logging.LogLevel`: logging severity level
                                 日志严重性级别
- `log_to_file::Bool`: if true, information will be logged to file besides REPL
                       如果为真，除REPL外，信息将被记录到文件中
- `assets_fingerprinted::Bool`: if true, asset fingerprinting is used in the asset pipeline
                                如果为真，则在资产管道中使用资产指纹(认证好理解点)
- `session_key_name::String`: the name of the session cookie
                              会话cookie的名称
- `session_storage::Symbol`: the backend adapter for session storage (default File)
                             会话存储的后端适配器(默认文件)
- `inflector_irregulars::Vector{Tuple{String,String}}`: additional irregular singular-plural forms to be used by the Inflector
                                                        变形器将使用其他不规则单数复数形式
- `run_as_server::Bool`: when true the server thread is launched synchronously to avoid that the script exits
                         如果为true，则同步启动服务器线程，以避免脚本退出
- `websockets_server::Bool`: if true, the websocket server is also started together with the web server
                             如果为true，则还将与Web服务器一起启动websocket服务器
- `html_parser_close_tag::String`: default " /". Can be changed to an empty string "" so the single tags would not be closed.
                                   默认为" /"。 可以更改为空字符串""，这样就不会关闭单个标签。
- `ssl_enabled::Bool`: default false. Server runs over SSL/HTTPS in development.
                       默认为false。 服务器在开发中通过SSL / HTTPS运行。
- `ssl_config::MbedTLS.SSLConfig`: default `nothing`. If not `nothing` and `ssl_enabled`, it will use the config to start the server over HTTPS.
                                   默认为"nothing"。 如果不是nothing和ssl_enabled，它将使用配置通过HTTPS启动服务器
"""
mutable struct Settings
  # 服务器端口
  server_port::Int
  #服务器ip
  server_host::String
  # 服务器根目录
  server_document_root::String
  # 处理服务器静态文件
  server_handle_static_files::Bool
  # 服务器签名
  server_signature::String
  # 应用环境
  app_env::String
  # 基站头信息
  cors_headers::Dict{String,String}
  # 基站允许源
  cors_allowed_origins::Vector{String}


  # 缓存时间
  cache_duration::Int
  # 缓存存储
  cache_storage::Symbol

  # 日志等级
  log_level::Logging.LogLevel
  # 日志是否保存到文件
  log_to_file::Bool

  # 资产(?，资源)-鉴定
  assets_fingerprinted::Bool

  # 会话 key 名称
  session_key_name::String
  # 会话存储
  session_storage::Symbol

  # 传播器-不定时
  inflector_irregulars::Vector{Tuple{String,String}}

  # 作为服务器运行
  run_as_server::Bool

  # 是否作为websocket服务器
  websockets_server::Bool
  # websocket端口
  websockets_port::Int

  # 设定项文件夹初始值
  initializers_folder::String

  # 路径-配置
  path_config::String
  # 路径-环境
  path_env::String
  # 路径-应用
  path_app::String
  # 路径-资源
  path_resources::String
  # 路径-库文件
  path_lib::String
  # 路径-助手
  path_helpers::String
  # 路径-日志
  path_log::String
  # 路径-任务
  path_tasks::String
  # 路径-构建
  path_build::String
  # 路径-插件
  path_plugins::String
  # 路径-缓存
  path_cache::String
  # 路径-构造器
  path_initializers::String
  # 路径-数据库
  path_db::String
  # 路径-二级制文件
  path_bin::String
  # 路径-源
  path_src::String

  # web管道-默认路由
  webchannels_default_route::String
  # web管道-js文件
  webchannels_js_file::String
  # web管道-订阅频道(?)
  webchannels_subscribe_channel::String
  # web管道-取消订阅频道(?)
  webchannels_unsubscribe_channel::String
  # web管道-默认路由
  webchannels_autosubscribe::Bool

  # html解析器-关闭标记
  html_parser_close_tag::String
  # html解析器-字符在(?)
  html_parser_char_at::String
  # html解析器-字符点(?)
  html_parser_char_dot::String
  # html解析器-字符列(?)
  html_parser_char_column::String
  # html解析器-字符破折符
  html_parser_char_dash::String

  # ssl证书启动
  ssl_enabled::Bool
  # ssl证书配置
  ssl_config::Union{MbedTLS.SSLConfig,Nothing}

  # 默认构造
  Settings(;
            server_port                 = (haskey(ENV, "PORT") ? parse(Int, ENV["PORT"]) : 8000), # default port for binding the web server
            server_host                 = ENV["HOST"],
            server_document_root        = "public",
            server_handle_static_files  = true,
            server_signature            = "Genie/$GENIE_VERSION/Julia/$VERSION",

            app_env                     = ENV["GENIE_ENV"],

            cors_headers  = Dict{String,String}(
              "Access-Control-Allow-Origin"       => "", # ex: "*" or "http://mozilla.org"
              "Access-Control-Expose-Headers"     => "", # ex: "X-My-Custom-Header, X-Another-Custom-Header"
              "Access-Control-Max-Age"            => "86400", # 24 hours
              "Access-Control-Allow-Credentials"  => "", # "true" or "false"
              "Access-Control-Allow-Methods"      => "", # ex: "POST, GET"
              "Access-Control-Allow-Headers"      => "", # ex: "X-PINGOTHER, Content-Type"
            ),
            cors_allowed_origins = String[],

            cache_duration    = 0,
            cache_storage     = :File,

            log_level     = Logging.Debug,
            log_to_file   = false,

            assets_fingerprinted  = false,

            session_key_name    = "__geniesid",
            session_storage     = :File,

            inflector_irregulars = Tuple{String,String}[],

            run_as_server = false,

            websockets_server = false,
            websockets_port   = server_port + 1,

            initializers_folder = "initializers",

            path_config         = "config",
            path_env            = joinpath(path_config, "env"),
            path_app            = "app",
            path_resources      = joinpath(path_app, "resources"),
            path_lib            = "lib",
            path_helpers        = joinpath(path_app, "helpers"),
            path_log            = "log",
            path_tasks          = "tasks",
            path_build          = buildpath(),
            path_plugins        = "plugins",
            path_cache          = "cache",
            path_initializers   = joinpath(path_config, initializers_folder),
            path_db             = "db",
            path_bin            = "bin",
            path_src            = "src",

            webchannels_default_route       = "__",
            webchannels_js_file             = "channels.js",
            webchannels_subscribe_channel   = "subscribe",
            webchannels_unsubscribe_channel = "unsubscribe",
            webchannels_autosubscribe       = true,

            html_parser_close_tag = " /",
            html_parser_char_at = "!!",
            html_parser_char_dot = "!",
            html_parser_char_column = "!",
            html_parser_char_dash = "__",

            ssl_enabled = false,
            ssl_config = nothing
        ) =
              new(
                  server_port, server_host,
                  server_document_root, server_handle_static_files, server_signature,
                  app_env,
                  cors_headers, cors_allowed_origins,
                  cache_duration, cache_storage,
                  log_level, log_to_file,
                  assets_fingerprinted,
                  session_key_name, session_storage,
                  inflector_irregulars,
                  run_as_server,
                  websockets_server, websockets_port,
                  initializers_folder,
                  path_config, path_env, path_app, path_resources, path_lib, path_helpers, path_log, path_tasks, path_build,
                  path_plugins, path_cache, path_initializers, path_db, path_bin, path_src,
                  webchannels_default_route, webchannels_js_file, webchannels_subscribe_channel, webchannels_unsubscribe_channel, webchannels_autosubscribe,
                  html_parser_close_tag, html_parser_char_at, html_parser_char_dot, html_parser_char_column, html_parser_char_dash,
                  ssl_enabled, ssl_config
                )
end

end
