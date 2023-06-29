any          = require 'lodash/some'
basicAuth    = require 'basic-auth'
compare      = require 'tsscmp'
fbaInit      = require '@/local/lib/fba-init'
Vault        = require '@/local/lib/arctic-vault'
{ DateTime } = require 'luxon'

module.exports = (type) ->

  web = (ctx, next) ->
    fba = await fbaInit()
    idToken = ctx.headers['firebase-auth-token']

    try
      decodedToken = await fba.auth().verifyIdToken(idToken)
      ctx.state.fbUser = { uid: decodedToken.uid }
      

    catch error
      ctx
      .unauthorized({ error: 'unauthorized' })
      .set({ 'WWW-Authenticate': 'Basic realm="Mutambo"' })
      return

    await next()
    return

  webMaybe = (ctx, next) ->
    fba = await fbaInit()
    idToken = ctx.headers['firebase-auth-token']

    try
      decodedToken = await fba.auth().verifyIdToken(idToken)
      ctx.state.fbUser = { uid: decodedToken.uid }
    catch e
      (->)(e) # Unauthorized OK

    await next()
    return

  api = (ctx, next) ->
    await next()
    return

  postmark = (ctx, next) ->
    vault = await Vault.open()
    user = basicAuth(ctx)
    if (any([
      !user
      !user.name
      !user.pass
      !compare(user.name, vault.secrets.kv.POSTMARK_WEBHOOK_NAME)
      !compare(user.pass, vault.secrets.kv.POSTMARK_WEBHOOK_PASS)
    ]))
      ctx
      .unauthorized({ error: 'unauthorized' })
      .set({ 'WWW-Authenticate': 'Basic realm="Mutambo"' })
    else
      await next()

  none = (ctx, next) ->
    await next()

  auth = switch type
    when 'api' then api
    when 'none' then none
    when 'postmark' then postmark
    when 'web' then web
    when 'webMaybe' then webMaybe
    else api

  return auth
