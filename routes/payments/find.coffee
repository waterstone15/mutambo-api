fbaHelpers      = require('@/local/lib/fba-helpers')
fbaInit         = require('@/local/lib/fba-init')
rand            = require('@/local/lib/rand')
User            = require('@/local/models/user')
{ all }         = require('rsvp')
{ DateTime }    = require('luxon')

module.exports = (ctx) ->
  { uid } = ctx.state.fbUser
  { code } = ctx.request.query

  if !uid
    ctx.unauthorized()
    return

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: { val: [ 'email' ], meta: ['id'] }})
  ])
  db = fba.firestore()

  pQS = await db.collection('/payments').where('val-code', '==', code).get()
  if pQS.empty
    ctx.badRequest()
    return

  payment = fbaHelpers.deserialize(pQS.docs[0].data())
  ctx.ok({ payment, user })
  return


