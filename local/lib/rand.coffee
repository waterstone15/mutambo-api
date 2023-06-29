naclInit = require('@/local/lib/nacl-init')

base36 = (len) ->
  nacl = await naclInit()
  chars = '0123456789abcdefghijklmnopqrstuvwxyz'
  str = ''
  for i in [0...len]
    rand_bytes = nacl.random_bytes(2)
    rand_hex = nacl.to_hex(rand_bytes)
    rand_int = parseInt(rand_hex, 16)
    str = str + chars[(rand_int % 36)]
  return str

base62 = (len) ->
  nacl = await naclInit()
  chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  str = ''
  for i in [0...len]
    rand_bytes = nacl.random_bytes(2)
    rand_hex = nacl.to_hex(rand_bytes)
    rand_int = parseInt(rand_hex, 16)
    str = str + chars[(rand_int % 62)]
  return str

module.exports = {
  base36
  base62
}
