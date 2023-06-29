convert      = require('@/local/lib/convert')
fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
includes     = require('lodash/includes')
isEmpty      = require('lodash/isEmpty')
pick         = require('lodash/pick')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')


module.exports = (ctx) ->

  game_id              = ctx.params.id
  { uid }              = ctx.state.fbUser
  { clock, iso, zone } = ctx.request.body
  zone = 'America/Chicago' || zone # TODO, implement zone picker in browser and drop override

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: ['id'] })
  ])
  db = fba.firestore()

  dt1 = DateTime.fromISO(iso)
  dt2 = DateTime.fromFormat(clock, "yyyy-LL-dd'T'HH:mm:ss", { zone })
  # https://moment.github.io/luxon/api-docs/index.html#datetimeequals
  if +dt1 != +dt2
    ctx.badRequest()
    return

  game = await fbaH.get('/games', game_id)
  if !game
    ctx.badRequest()
    return

  accessDS = await db.collection("/seasons/#{game.rel.season}/users").doc(user.meta.id).get()
  if !includes(accessDS.data()['access-control'], 'admin')
    ctx.unauthorized()
    return

  updates =
    val:
      start_clock_time: clock
      start_timezone: zone
      start_iso: iso
  updates_s = fbaH.serialize(updates)

  _wb = db.batch()
  _wb.set(db.collection('/games').doc(game.meta.id), updates_s, { merge: true })
  await _wb.commit()

  ctx.ok({})
  return
