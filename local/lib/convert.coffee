_        = require('lodash')
chunk    = require('lodash/chunk')
indexOf  = require('lodash/indexOf')
join     = require('lodash/join')
naclInit = require('@/local/lib/nacl-init')
padStart = require('lodash/padStart')
parseInt = require('lodash/parseInt')


fromBase32 = (b32) ->
  nacl = await naclInit()
  range = '0123456789abcdefghijklmnopqrstuv'.split('')

  binary = _(b32)
    .split('')
    .map((val, i, coll) ->
      base10 = indexOf(range, val)
      base2 = base10.toString(2)
      return if i == (coll.length - 1) then base2 else padStart(base2, 5, '0')
    )
    .join('')

  chunked = _(binary)
    .chunk(8)
    .map((chunk) -> parseInt(join(chunk, ''), 2))
    .value()

  unit8 = new Uint8Array(chunked)

  return nacl.decode_utf8(unit8)


toBase32 = (string) ->
  nacl = await naclInit()

  unit8 = nacl.encode_utf8(string)

  binary = _(unit8)
    .map((i) -> padStart(i.toString(2), 8, '0'))
    .reduce((acc, value) ->
      acc = "#{acc}#{value}"
    , '')

  chunked = chunk(binary, 5)

  base32 = _(chunked)
    .map((chunk) -> parseInt(join(chunk, ''), 2).toString(32))
    .reduce((acc, value) ->
      acc = "#{acc}#{value}"
    , '')

  return base32

toHashedBase32 = (string, options) ->
  opts = { algo: 'crypto_hash' } # sha512
  opts.algo = 'crypto_hash_sha256' if options?.algo == 'sha256'

  nacl = await naclInit()

  unit8 = nacl.encode_utf8(string)
  hash = nacl[opts.algo](unit8)
  base16 = nacl.to_hex(hash)

  chunked = chunk(base16, 2)

  base32 = _(chunked)
    .map((chunk) ->
      (parseInt(chunk[0], 16) + parseInt(chunk[1] ? 0, 16)).toString(32)
    )
    .reduce((acc, value) ->
      acc = "#{acc}#{value}"
    , '')

  return base32

module.exports = {
  fromBase32
  toBase32
  toHashedBase32
}
