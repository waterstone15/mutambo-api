fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
includes     = require('lodash/includes')
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
  { player, team } = ctx.request.body

  teams = []
  season = { id: '' }
  league = { id: '' }

  league_captain_count = 0
  league_player_count = 0
  league_team_count = 0
  season_captain_count = 0
  season_player_count = 0
  season_team_count = 0
  team_role_count = 0

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: [] })
  ])
  db = fba.firestore()

  [ teamDS, teamUserDS, teamPlayerDS, playerTeamsQS, playerRegistrationQS ] = await all([
    db.collection('/teams').doc(team.id).get(),
    db.collection("/teams/#{team.id}/users").doc(user.id).get(),
    db.collection("/teams/#{team.id}/users").doc(player.id).get(),
    db.collection("/users/#{player.id}/teams").get(),
    db.collection("/registrations")
      .where('rel-user', '==', player.id)
      .where('rel-team', '==', team.id)
      .where('meta-type', '==', 'registration-league-season-player')
      .get()
  ])

  if (
    !teamDS.exists ||
    !teamPlayerDS.exists ||
    !teamUserDS.exists ||
    playerRegistrationQS.empty ||
    playerTeamsQS.empty ||
    !includes(teamPlayerDS.data()['access-control'], 'player')
  )
    ctx.badRequest()
    return

  if !includes(teamUserDS.data()['access-control'], 'captain')
    ctx.unauthorized()
    return

  registration = fbaH.deserialize(playerRegistrationQS.docs[0].data())

  league.id = teamDS.data().league
  season.id = teamDS.data().season

  [ leaguePlayerDS, seasonPlayerDS ] = await all([
    db.collection("/leagues/#{league.id}/users").doc(player.id).get()
    db.collection("/seasons/#{season.id}/users").doc(player.id).get()
  ])

  league_role_count = leaguePlayerDS.data()['access-control'].length
  season_role_count = seasonPlayerDS.data()['access-control'].length
  team_role_count = teamPlayerDS.data()['access-control'].length

  await all(map(playerTeamsQS.docs, (doc) ->
    [ _t, _r ] = await all([
      db.collection('teams').doc(doc.id).get()
      db.collection("/teams/#{doc.id}/users").doc(player.id).get()
    ])
    _team = _t.data()
    _roles = _r.data()['access-control']

    league_captain_count += 1 if (_team.league == league.id && includes(_roles, 'captain'))
    league_player_count += 1  if (_team.league == league.id && includes(_roles, 'player'))
    league_team_count += 1    if (_team.league == league.id)
    season_captain_count += 1 if (_team.season == season.id && includes(_roles, 'captain'))
    season_player_count += 1  if (_team.season == season.id && includes(_roles, 'player'))
    season_team_count += 1    if (_team.season == season.id)
    return
  ))

  _wb = db.batch()

  # If the player has additional roles on the team, remove the player role.
  if team_role_count > 1
    _wb.set(db.collection("/teams/#{team.id}/users").doc(player.id), { 'access-control': fba.firestore.FieldValue.arrayRemove('player') }, { merge: true })

  # If the player has no additional roles on the team, remove the player from the team.
  if team_role_count <= 1
    _wb.delete(db.collection("/teams/#{team.id}/users").doc(player.id))
    _wb.delete(db.collection("/users/#{player.id}/teams").doc(team.id))

  # If the player only has a player role in the league, and this is their only team in that league, remove the player from the league
  if league_role_count <= 1 && league_team_count <= 1
    _wb.delete(db.collection("/leagues/#{league.id}/users").doc(player.id))
    _wb.delete(db.collection("/users/#{player.id}/leagues").doc(league.id))

  # If a player has more than 1 role in the league, but this is their only player role, remove their player role from the league.
  if league_role_count > 1 && league_player_count <= 1
    _wb.set(db.collection("/leagues/#{league.id}/users").doc(player.id), { 'access-control': fba.firestore.FieldValue.arrayRemove('player') }, { merge: true })

  # If the player only has a player role in the season, and this is their only team in that season, remove the player from the season
  if season_role_count <= 1 && season_team_count <= 1
    _wb.delete(db.collection("/season/#{season.id}/users").doc(player.id))
    _wb.delete(db.collection("/users/#{player.id}/seasons").doc(season.id))

  # If this is the only player role in this season, remove their player role from the season,
  # And never remove registrations? TODO
  if season_player_count <= 1
    _wb.set(db.collection("/seasons/#{season.id}/users").doc(player.id), { 'access-control': fba.firestore.FieldValue.arrayRemove('player') }, { merge: true })
    # _wb.set(db.collection('/registrations').doc(registration.meta.id), { 'meta-deleted': true }, { merge: true })
    # _wb.delete(db.collection("/leagues/#{league.id}/registrations").doc(registration.meta.id))
    # _wb.delete(db.collection("/seasons/#{season.id}/registrations").doc(registration.meta.id))
    # _wb.delete(db.collection("/users/#{player.id}/registrations").doc(registration.meta.id))


  await _wb.commit()

  ctx.ok({})
  return
