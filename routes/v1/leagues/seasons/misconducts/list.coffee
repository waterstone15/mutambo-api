blackout     = require '@/local/lib/blackout'
capitalize   = require 'lodash/capitalize'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
toLower      = require 'lodash/toLower'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id } = ctx.request.body

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

  if !season || !user
    ctx.badRequest()
    return

  opts =
    filters: [[ 'rel-season', '==', season.meta.id]]
    orderBy: [[ 'meta-created-at' ]]
  misconducts = await fbaH.findAll("/misconducts", opts)

  misconducts = await all(map(misconducts, (m) ->
    player = await fbaH.get('/users', m.rel.user, { fields: [ 'meta-id', 'val-full-name' ]})
    team = await fbaH.get('/teams', m.rel.team, { fields: [ 'meta-id', 'val-name' ]})
    return merge(m, {
      val:
        user: player
        team: team
      ui:
        duration: 'Arbitrary'
        status: capitalize(m.val.status)
        suspended_at: DateTime.fromISO(m.val.suspended_at).toFormat('yyyy-MM-dd')
        reinstated_at: if m.val.reinstated_at then DateTime.fromISO(m.val.reinstated_at).toFormat('yyyy-MM-dd') else null
    })
  ))

  ctx.ok({ misconducts: misconducts })
  return
