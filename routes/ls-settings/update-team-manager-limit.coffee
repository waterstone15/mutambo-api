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
  { team_manager_limit, season } = ctx.request.body

  [ fba, season, user ] = await all([
    fbaI()
    Season.get(season.meta.id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  tml = team_manager_limit
  tml_ok = isNumber(tml) && (0 <= tml <= 5)

  roles = await fbaH.retrieve("/seasons/#{season.meta.id}/users", user.meta.id)

  if !roles || !tml_ok
    ctx.badRequest()
    return

  if !includes(roles['access-control'], 'admin')
    ctx.unauthorized()
    return

  updates = fbaH.serialize(
    val:
      settings: merge(season.val.settings, { team_manager_limit })
  )

  wb = db.batch()
  wb.set(db.collection('/seasons').doc(season.meta.id), updates, { merge: true })
  await wb.commit()

  ctx.ok({})
  return
