fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
includes     = require 'lodash/includes'
intersection = require 'lodash/intersection'
isEmpty      = require 'lodash/isEmpty'
Notification = require '@/local/models/flame/notification'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { team_id, player_id, season_id, notes } = ctx.request.body

  fba = await fbaI()
  db  = fba.firestore()

  P1 = ->
    user = await User.getByUid(uid)
    user_access = await fbaH.retrieve("/teams/#{team_id}/users", user.meta.id)
    user_is_manager = !isEmpty(intersection(user_access['access-control'], [ 'manager', 'captain' ]))
    return { user, user_is_manager }

  P2 = ->
    player_access = await fbaH.retrieve("/teams/#{team_id}/users", player_id)
    player_is_player = includes(player_access['access-control'], 'player')
    return player_is_player

  P3 = ->
    season = await fbaH.get('/seasons', season_id)
    league = await fbaH.get('/leagues', season.rel.league)
    return { league, season }

  [ team, player, { user, user_is_manager }, player_is_player, { league, season } ] = await all([
    fbaH.get('/teams', team_id)
    fbaH.get('/users', player_id)
    P1()
    P2()
    P3()
  ])

  if !player_is_player || !user_is_manager || team.rel.season != season.meta.id
    ctx.badRequest()
    return

  n = Notification.create({
    meta:
      subtype: 'league-season'
    val:
      type: 'league-season-team-request-to-remove-player'
      title: 'Request to Remove Player'
      body: "#{user.val.full_name} has requested #{player.val.full_name} be removed from #{team.val.name}."
      data:
        rel:
          manager: user.meta.id
          player: player.meta.id
          team: team.meta.id
        val:
          notes: if !isEmpty(notes) then notes else null
    rel:
      season: season.meta.id
  })
  n = await n.save()

  ctx.ok({})
  return

