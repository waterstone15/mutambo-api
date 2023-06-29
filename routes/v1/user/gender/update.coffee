fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
lowerCase    = require 'lodash/lowerCase'
merge        = require 'lodash/merge'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { gender } = ctx.request.body

  gender = lowerCase(trim(gender))

  if isEmpty(gender) || !includes(['female', 'male', 'other'], gender)
    ctx.badRequest()
    return

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: [ 'id' ] })
  ])
  db = fba.firestore()

  if !user.meta.id
    ctx.badRequest()
    return

  now = DateTime.local().setZone('utc').toISO()
  obj =
    val: gender: gender
    meta: updated_at: now

  updates = fbaH.serialize(obj)

  wb = db.batch()
  wb.set(db.collection('/users').doc(user.meta.id), updates, { merge: true })
  await wb.commit()

  ctx.ok({})
