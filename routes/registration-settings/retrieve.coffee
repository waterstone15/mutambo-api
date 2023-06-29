fbaInit  = require('@/local/lib/fba-init')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  if !uid
    ctx.unauthorized()
    return

  fba = await fbaInit()
  db = fba.firestore()

  ds = await db.collection('/registration-settings').doc(id).get()
  if !ds.exists
    ctx.badRequest()
    return

  ctx.ok({ registration_settings: ds.data() })
