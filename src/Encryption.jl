"""
Provides Genie with encryption and decryption capabilities.
"""
module Encryption

import Genie, Nettle

const ENCRYPTION_METHOD = "AES256"


"""
    encrypt{T}(s::T) :: String

Encrypts `s`.
"""
function encrypt(s::T)::String where T
  (key32, iv16) = encryption_sauce()
  encryptor = Nettle.Encryptor(ENCRYPTION_METHOD, key32)

  Nettle.encrypt(encryptor, :CBC, iv16, Nettle.add_padding_PKCS5(Vector{UInt8}(s), 16)) |> bytes2hex
end


"""
    decrypt(s::String) :: String

Decrypts `s` (a `string` previously encrypted by Genie).
"""
function decrypt(s::String) :: String
  (key32, iv16) = encryption_sauce()
  decryptor = Nettle.Decryptor(ENCRYPTION_METHOD, key32)
  deciphertext = Nettle.decrypt(decryptor, :CBC, iv16, s |> hex2bytes)

  String(Nettle.trim_padding_PKCS5(deciphertext))
end


"""
    encryption_sauce() :: Tuple{Vector{UInt8},Vector{UInt8}}

Generates a pair of key32 and iv16 with salt for encryption/decryption
"""
function encryption_sauce() :: Tuple{Vector{UInt8},Vector{UInt8}}
  if ! isdefined(Genie, :SECRET_TOKEN)
    @error "Encryption error: Genie.SECRET_TOKEN not defined"

    if ! Genie.Configuration.isprod()
      @warn "Generating temporary secret token"
      Core.eval(Genie, :(const SECRET_TOKEN = $(Genie.Generator.secret_token())))
    else
      error("Can't encrypt - please make sure you run a Genie project and SECRET_TOKEN is defined in config/secrets.jl")
    end
  elseif length(Genie.SECRET_TOKEN) < 64
    @error "Encryption error: Invalid Genie.SECRET_TOKEN"

    if ! Genie.Configuration.isprod()
      @warn "Regenerating temporary secret token"
      Core.eval(Genie, :(SECRET_TOKEN = $(Genie.Generator.secret_token())))
    else
      error("Can't encrypt - please make sure you run a Genie project and SECRET_TOKEN is defined in config/secrets.jl")
    end
  end

  passwd = Genie.SECRET_TOKEN[1:32]
  salt = hex2bytes(Genie.SECRET_TOKEN[33:64])

  Nettle.gen_key32_iv16(Vector{UInt8}(passwd), salt)
end

end
