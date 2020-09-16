"""
Collection of utilities for working with Responses data
"""
module Responses

import Genie, Genie.Router
import HTTP

export getresponse, getheaders, setheaders, setheaders!, getstatus, setstatus, setstatus!, getbody, setbody, setbody!


function getresponse() :: HTTP.Response
  Router.@params(Genie.PARAMS_RESPONSE_KEY)
end


function getheaders(res::HTTP.Response) :: Dict{String,String}
  Dict{String,String}(res.headers)
end
function getheaders() :: Dict{String,String}
  getheaders(getresponse())
end


function setheaders!(res::HTTP.Response, headers::Dict) :: HTTP.Response
  push!(res.headers, [headers...]...)

  res
end
function setheaders(headers::Dict) :: HTTP.Response
  setheaders!(getresponse(), headers)
end
function setheaders(header::Pair{String,String}) :: HTTP.Response
  setheaders(Dict(header))
end
function setheaders(headers::Vector{Pair{String,String}}) :: HTTP.Response
  setheaders(Dict(headers...))
end


function getstatus(res::HTTP.Response) :: Int
  res.status
end
function getstatus() :: Int
  getstatus(getresponse())
end


function setstatus!(res::HTTP.Response, status::Int) :: HTTP.Response
  res.status = status

  res
end
function setstatus(status::Int) :: HTTP.Response
  setstatus!(getresponse(), status)
end


function getbody(res::HTTP.Response) :: String
  String(res.body)
end
function getbody() :: String
  getbody(getresponse())
end


function setbody!(res::HTTP.Response, body::String) :: HTTP.Response
  res.body = collect(body)

  res
end
function setbody(body::String) :: HTTP.Response
  setbody!(getresponse(), body)
end

end
