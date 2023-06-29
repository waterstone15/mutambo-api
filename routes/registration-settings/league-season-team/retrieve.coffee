fbaInit = require('@/local/lib/fba-init')
fbaHelpers = require('@/local/lib/fba-helpers')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  if !uid
    ctx.unauthorized()
    return

  fba = await fbaInit()
  db = fba.firestore()

  id = "registration-settings-#{id}" if /ltrs/.test(id) && !/registration-settings/.test(id)

  ds = await db.collection('/registration-settings').doc(id).get()
  if !ds.exists
    ctx.badRequest()
    return


  registration_settings = fbaHelpers.deserialize(ds.data())

  ctx.ok({ registration_settings })