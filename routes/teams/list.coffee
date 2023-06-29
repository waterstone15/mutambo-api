fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
map          = require('lodash/map')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
reverse      = require('lodash/reverse')
sortBy       = require('lodash/sortBy')
unionBy      = require('lodash/unionBy')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([ fbaI(), User.getByUid(uid, { values: meta: ['id'] }) ])
  db = fba.firestore()

  tIDsQS = await db.collection("/users/#{user.meta.id}/teams").get()
  tIDs   = filter(map((tIDsQS.docs ? []), (tDS) -> if ('2022' > DateTime.fromSeconds(tDS.createTime.seconds).toISO()) then null else tDS.id))

  teams = await all(map((tIDs), (id) ->
    [ team, rolesDS ] = await all([
      fbaH.get('/teams', id)
      db.collection("/teams/#{id}/users").doc(user.meta.id).get()
    ])
    return null if (team.meta.v != 2)

    [ division, league, season, ] = await all([
      if team.rel.division then fbaH.get('/division', team.rel.division) else {}
      if team.rel.league   then fbaH.get('/leagues', team.rel.league)     else {}
      if team.rel.season   then fbaH.get('/seasons', team.rel.season)     else {}
    ])
    league = pick(league, [ 'meta.id', 'val.name' ])
    roles  = rolesDS.data()['access-control']
    season = pick(season, [ 'meta.id', 'val.name' ])

    team = merge(team, { val: { division, league, roles, season }})
    return team
  ))

  teams = filter(teams)
  ctx.ok({ teams })
  return
