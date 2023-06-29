fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
SeasonToUser = require '@/local/models/season-to-user'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { misconduct_id } = ctx.request.body

  [ fba, misconduct, user ] = await all([
    fbaI()
    fbaH.get('/misconducts', misconduct_id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  season = { meta: { id: misconduct.rel.season }}

  authorized = await SeasonToUser.anyRole({ season, user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()
    return

  if !season || !user || !misconduct
    ctx.badRequest()
    return

  now = DateTime.local().setZone('utc')

  updates =
    meta:
      updated_at: now.toISO()
    val:
      reinstated_at: now.toISO()
      status: 'reinstated'

  obj = fbaH.serialize(updates)
  await db.collection('/misconducts').doc(misconduct.meta.id).update(obj)

  ctx.ok({})
  return
