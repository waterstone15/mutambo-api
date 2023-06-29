base64     = require '@stablelib/base64'
utf8       = require '@stablelib/utf8'
{ SHA256 } = require '@stablelib/sha256'

key = ({ length, seed }) ->
  word_unit8 = utf8.encode(seed)
  hash = new SHA256()
  hash.update(word_unit8)
  s256 = hash.digest()
  b16  = base64.encodeURLSafe(s256)

module.exports = {
  key
}
