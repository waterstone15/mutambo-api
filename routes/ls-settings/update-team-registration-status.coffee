fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
includes     = require('lodash/includes')
isNumber     = require('lodash/isNumber')
merge        = require('lodash/merge')
Season       = require('@/local/models/season')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { status, season } = ctx.request.body

  [ fba, season, user ] = await all([
    fbaI()
    Season.get(season.meta.id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  status_ok = includes([ 'open', 'closed', 'schedule' ], status)

  roles = await fbaH.retrieve("/seasons/#{season.meta.id}/users", user.meta.id)

  if !roles || !status_ok
    ctx.badRequest()
    return

  if !includes(roles['access-control'], 'admin')
    ctx.unauthorized()
    return

  updates = fbaH.serialize(
    val:
      settings: merge(season.val.settings, { team_registration_status: status })
  )

  wb = db.batch()
  wb.set(db.collection('/seasons').doc(season.meta.id), updates, { merge: true })
  await wb.commit()

  ctx.ok({})
  return
