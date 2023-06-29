fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
includes     = require('lodash/includes')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id } = ctx.request.query

  [ fba, season, user ] = await all([
    fbaI()
    fbaH.get('/seasons', season_id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  rolesDS = await db.collection("/seasons/#{season.meta.id}/users").doc(user.meta.id).get()
  roles   = rolesDS.data()['access-control']
  if !includes(roles, 'admin')
    ctx.unauthorized()
    return

  opts =
    filters: [['rel-season', '==', season.meta.id]]
    orderBy: [[ 'val-name' ]]
  divisions = await fbaH.findAll('/divisions', opts)

  ctx.ok({ divisions })
  return



