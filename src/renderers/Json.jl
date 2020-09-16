module Json

import Revise
import JSON, HTTP
using Genie, Genie.Renderer

const JSONParser = JSON
const JSON_FILE_EXT = ".json.jl"
const JSONString = String

export JSONString, json


function render(viewfile::Genie.Renderer.FilePath; context::Module = @__MODULE__, vars...) :: Function
  Genie.Renderer.registervars(vars...)
  Genie.Renderer.injectvars(context)

  () -> (Base.include(context, string(viewfile)) |> JSONParser.json)
end


function render(data::Any; forceparse::Bool = false, context::Module = @__MODULE__) :: Function
  () -> JSONParser.json(data)
end


function Genie.Renderer.render(::Type{MIME"application/json"}, datafile::Genie.Renderer.FilePath; context::Module = @__MODULE__, vars...) :: Genie.Renderer.WebRenderable
  Genie.Renderer.WebRenderable(render(datafile; context = context, vars...), :json)
end


function Genie.Renderer.render(::Type{MIME"application/json"}, data::String; context::Module = @__MODULE__, vars...) :: Genie.Renderer.WebRenderable
  Genie.Renderer.WebRenderable(render(data; context = context, vars...), :json)
end


function Genie.Renderer.render(::Type{MIME"application/json"}, data::Any; context::Module = @__MODULE__, vars...) :: Genie.Renderer.WebRenderable
  Genie.Renderer.WebRenderable(render(data), :json)
end

### json API

function json(resource::Genie.Renderer.ResourcePath, action::Genie.Renderer.ResourcePath; context::Module = @__MODULE__,
              status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), vars...) :: Genie.Renderer.HTTP.Response
  json(Genie.Renderer.Path(joinpath(Genie.config.path_resources, string(resource), Renderer.VIEWS_FOLDER, string(action) * JSON_FILE_EXT));
        context = context, status = status, headers = headers, vars...)
end


function json(datafile::Genie.Renderer.FilePath; context::Module = @__MODULE__,
              status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), vars...) :: Genie.Renderer.HTTP.Response
  Genie.Renderer.WebRenderable(Genie.Renderer.render(MIME"application/json", datafile; context = context, vars...), :json, status, headers) |> Genie.Renderer.respond
end


function json(data::String; context::Module = @__MODULE__,
              status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders(), vars...) :: Genie.Renderer.HTTP.Response
  Genie.Renderer.WebRenderable(Genie.Renderer.render(MIME"application/json", data; context = context, vars...), :json, status, headers) |> Genie.Renderer.respond
end


function json(data::Any; status::Int = 200, headers::Genie.Renderer.HTTPHeaders = Genie.Renderer.HTTPHeaders()) :: Genie.Renderer.HTTP.Response
  Genie.Renderer.WebRenderable(Genie.Renderer.render(MIME"application/json", data), :json, status, headers) |> Genie.Renderer.respond
end


### === ###
### EXCEPTIONS ###


function Genie.Router.error(error_message::String, ::Type{MIME"application/json"}, ::Val{500}; error_info::String = "") :: HTTP.Response
  json(Dict("error" => "500 Internal Error - $error_message", "info" => error_info), status = 500)
end


function Genie.Router.error(error_message::String, ::Type{MIME"application/json"}, ::Val{404}; error_info::String = "") :: HTTP.Response
  json(Dict("error" => "404 Not Found - $error_message", "info" => error_info), status = 404)
end


function Genie.Router.error(error_code::Int, error_message::String, ::Type{MIME"application/json"}; error_info::String = "") :: HTTP.Response
  json(Dict("error" => "$error_code Error - $error_message", "info" => error_info), status = error_code)
end

end