base64   = require('@stablelib/base64')
fetch    = require('node-fetch')
hex      = require('@stablelib/hex')
isString = require('lodash/isString')
merge    = require('lodash/merge')
nacl     = require('tweetnacl')
utf8     = require('@stablelib/utf8')

module.exports = (->

  _cache = {
    default: null
  }

  _open = (opts = {}) ->

    if _cache.default
      return _cache.default

    id    = opts.id    ? process.env.VAULT_ID    ? null
    key   = opts.key   ? process.env.VAULT_KEY   ? null
    token = opts.token ? process.env.VAULT_TOKEN ? null

    if !id || !key || !token
      console.log 'Auth token, secret group id, and group key are all required to initialize Arctic Vault.'
      return {}

    try
      url  = "https://api.arctic-vault.com/api/1/secret-groups/#{id}"
      opts =
        headers: { 'arctic-vault-api-token': token }
        method: 'GET'
      res = await fetch(url, opts)
      data = await res.json()
      group = data.group
    catch e
      console.log e
      return {}

    vault = { secrets: { kv: [] }}

    if !!group.val.secrets_box_b64
      group.val.key         = hex.decode(key)
      group.val.secrets_box = base64.decode(group.val.secrets_box_b64)
      group.val.nonce       = base64.decode(group.val.nonce_b64)
      group.val.secrets     = JSON.parse(utf8.decode(nacl.secretbox.open(group.val.secrets_box, group.val.nonce, group.val.key)))

      for s, i in group.val.secrets
        vault.secrets.kv[group.val.secrets[i].val.key] = group.val.secrets[i].val.value

    _cache.default = vault

    return vault



  # ---------------------------------------------------------------------------


  return {
    open: _open
  }


)()

