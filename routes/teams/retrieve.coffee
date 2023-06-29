fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
includes     = require('lodash/includes')
ILLSTP       = require('@/local/models/invite-link/league-season-team-player')
ILLSTM       = require('@/local/models/invite-link/league-season-team-manager')
League       = require('@/local/models/league')
map          = require('lodash/map')
merge        = require('lodash/merge')
omit         = require('lodash/omit')
pick         = require('lodash/pick')
reverse      = require('lodash/reverse')
Season       = require('@/local/models/season')
some         = require('lodash/some')
sortBy       = require('lodash/sortBy')
Team         = require('@/local/models/team')
toLower      = require('lodash/toLower')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: [ 'id' ] })
  ])

  db = fba.firestore()

  [ team, managerIL, playerIL, rolesDS,  ] = await all([
    Team.get(id)
    ILLSTM.getByTeam(id)
    ILLSTP.getByTeam(id)
    db.collection("/teams/#{id}/users").doc(user.meta.id).get()
  ])

  team.val.roles = rolesDS.data()['access-control']
  team.val.isCaptain = includes(team.val.roles, 'captain')
  team.val.isManager = includes(team.val.roles, 'captain') || includes(team.val.roles, 'manager')
  team.val.isPlayer = includes(team.val.roles, 'player')

  if !some([
    includes(team.val.roles , 'captain')
    includes(team.val.roles , 'manager')
    includes(team.val.roles , 'player')
  ])
    ctx.unauthorized({})
    return

  if !playerIL
    playerIL = await ILLSTP.create({
      team_id: team.meta.id
      season_id: team.rel.season
      league_id: team.rel.league
    })

  if !managerIL
    managerIL = await ILLSTM.create({
      team_id: team.meta.id
      season_id: team.rel.season
      league_id: team.rel.league
    })

  team.val.player_invite_link = playerIL
  team.val.manager_invite_link = managerIL

  if !some([ includes(team.val.roles , 'captain'), includes(team.val.roles , 'manager') ])
    team = omit(team, [
      'meta.created_by'
      'rel.manager_invite_link'
      'rel.payment'
      'rel.player_invite_link'
      'rel.registration'
      'val.manager_invite_link'
      'val.notes'
      'val.player_invite_link'
    ])

  [ league, season, usersQS ] = await all([
    League.get(team.rel.league)
    Season.get(team.rel.season)
    db.collection("/teams/#{team.meta.id}/users").get()
  ])

  members = await all(map(usersQS.docs ? [], (doc) ->
    if includes(team.val.roles, 'captain') || includes(team.val.roles, 'manager')
      member = await User.get(doc.id, { values: { val: [ 'display_name', 'full_name', 'email' ], meta: [ 'id' ] }})
    else
      member = await User.get(doc.id, { values: { val: [ 'display_name' ], meta: [ 'id' ] }})

    return merge(member, {
      roles: doc.data()['access-control']
      isManager: includes(doc.data()['access-control'], 'captain') || includes(doc.data()['access-control'], 'manager')
      isCaptain: includes(doc.data()['access-control'], 'captain')
      isPlayer: includes(doc.data()['access-control'], 'player')
    })
  ))
  team.val.members = sortBy(members, (m) -> toLower(m.val.name))

  if league then team.val.league = pick(league, [ 'meta.id', 'val.name' ])
  if season then team.val.season = pick(season, [ 'meta.id', 'val.name' ])

  ctx.ok({ team })
  return
