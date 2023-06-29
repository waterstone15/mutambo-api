base64     = require '@stablelib/base64'
utf8       = require '@stablelib/utf8'
{ SHA256 } = require '@stablelib/sha256'

sha256 = (str) ->
  word_unit8 = utf8.encode(str)
  hash = new SHA256()
  hash.update(word_unit8)
  s256 = hash.digest()
  b64  = base64.encodeURLSafe(s256)
  hash = null
  return b64

module.exports = {
  sha256 
}