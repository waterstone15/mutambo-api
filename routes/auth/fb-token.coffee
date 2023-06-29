Account      = require('@/local/models/account')
fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
{ DateTime } = require('luxon')

module.exports = (ctx) ->

  { code } = ctx.request.query

  fba = await fbaI()
  db  = fba.firestore()

  ac = await fbaH.get('/auth-codes', "auth-code-#{code}")
  if !ac
    ctx.badRequest()
    return

  expires_at = DateTime.fromISO(ac.meta.created_at).plus({ minutes: 10 }).setZone('utc')
  now        = DateTime.local().setZone('utc')

  isExpired = now > expires_at
  if isExpired
    ctx.unauthorized()
    return

  try
    fbUser = await fba.auth().getUserByEmail(ac.val.email)
  catch e
    fbUser = await fba.auth().createUser({
      email: ac.val.email
      emailVerified: true
    })
    await Account.create(fbUser.uid)

  token = await fba.auth().createCustomToken(fbUser.uid)

  ctx.ok({ token })
  return

