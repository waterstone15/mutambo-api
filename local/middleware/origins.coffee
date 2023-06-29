any       = require('lodash/some')
map       = require('lodash/map')
Vault     = require('@/local/lib/arctic-vault')

module.exports = (opts) ->

  origins = (ctx, next) ->
    vault = await Vault.open()
    ne = vault.secrets.kv.NODE_ENV

    if any(map(opts, ({ env, match }) -> (ne == env && !match.test(ctx.origin))))
      ctx.unauthorized()
      return

    await next()
    return

  return origins