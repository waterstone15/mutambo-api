fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
pick         = require 'lodash/pick'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


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

  tQS = await db
    .collection('/teams')
    .where('rel-season', '==', season.meta.id)
    .get()

  teams = await all(map((tQS.docs ? []), (tDS) ->
    if ('2022' > DateTime.fromSeconds(tDS.createTime.seconds).toISO())
      return null

    fields = [
      'meta.created_at'
      'meta.created_by'
      'meta.id'
      'val.name'
      'val.player_count'
      'val.manager_count'
    ]
    team = pick(fbaH.deserialize(tDS.data()), fields)
    team.val.manager_count = team.val.manager_count ? 0
    team.val.player_count = team.val.player_count ? 0

    if tDS.data()['rel-division']
      division = await fbaH.get('/divisions', tDS.data()['rel-division'])
      team.val.division = pick(division, [ 'meta.id', 'val.name' ])

    return team
  ))

  teams = filter(teams)
  teams = filter(teams, (t) -> t.meta.created_by != 'Cj6nbEFWyXQm4NL2W9T9HSZRH242')

  ctx.ok({ teams })
  return



