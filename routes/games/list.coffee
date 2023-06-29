fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([ fbaI(), User.getByUid(uid, { values: meta: ['id'] }) ])
  db = fba.firestore()

  tIDsQS = await db.collection("/users/#{user.meta.id}/teams").get()
  tIDs   = filter(map((tIDsQS.docs ? []), (tDS) -> if ('2022' > DateTime.fromSeconds(tDS.createTime.seconds).toISO()) then null else tDS.id))

  games = []
  await all(map((tIDs), (id) ->
    [ ags, hgs] = await all([
      fbaH.findAll('/games', { filters: [[ 'rel-away-team', '==', id ]] })
      fbaH.findAll('/games', { filters: [[ 'rel-home-team', '==', id ]] })
    ])
    games = [...games, ...(ags ? []), ...(hgs ? [])]
  ))

  divisions = {}
  teams = {}

  divisionsPs = all(map(games, (game) ->
    if !divisions[game.rel.division]
      divisions[game.rel.division] = {}
      divisions[game.rel.division] = await fbaH.get('/divisions', game.rel.division, { fields: [ 'meta-id', 'val-name' ] })
  ))

  gamesPs = all(map(games, (game) ->

    if !teams[game.rel.away_team]
      teams[game.rel.away_team] = {}
      [ rolesDS, team ] = await all([
        db.collection("/teams/#{game.rel.away_team}/users").doc(user.meta.id).get()
        fbaH.get('/teams', game.rel.away_team, { fields: [ 'meta-id', 'val-name' ] })
      ])
      roles = if rolesDS.exists then rolesDS.data()['access-control'] else []
      teams[game.rel.away_team] = merge(team, { val: { roles: roles }})

    if !teams[game.rel.home_team]
      teams[game.rel.home_team] = {}
      [ rolesDS, team ] = await all([
        db.collection("/teams/#{game.rel.home_team}/users").doc(user.meta.id).get()
        fbaH.get('/teams', game.rel.home_team, { fields: [ 'meta-id', 'val-name' ] })
      ])
      roles = if rolesDS.exists then rolesDS.data()['access-control'] else []
      teams[game.rel.home_team] = merge(team, { val: { roles: roles }})

    return
  ))

  await all([ divisionsPs, gamesPs ])

  games = map(games, (game) ->
    game = merge(game, {
      ui:
        can_print_roster: (DateTime.local().setZone(game.val.start_timezone).minus({ hours: 48 }) < DateTime.fromISO(game.val.start_clock_time, { zone: game.val.start_timezone}).startOf('day') && DateTime.local().setZone(game.val.start_timezone).plus({ hours: 48 }) > DateTime.fromISO(game.val.start_clock_time, { zone: game.val.start_timezone }).startOf('day') && (includes(teams[game.rel.home_team].val.roles, 'captain') || includes(teams[game.rel.away_team].val.roles, 'captain') || includes(teams[game.rel.home_team].val.roles, 'manager') || includes(teams[game.rel.away_team].val.roles, 'manager')))
        date_formatted: DateTime.fromISO(game.val.start_clock_time, { zone: game.val.start_timezone }).toFormat('MMMM d, yyyy')
        time_formatted: DateTime.fromISO(game.val.start_clock_time, { zone: game.val.start_timezone }).toFormat('h:mm a ZZZZ')
      val:
        away_team: teams[game.rel.away_team]
        home_team: teams[game.rel.home_team]
        division: divisions[game.rel.division]
    })
    return game
  )

  games = filter(games)
  games = sortBy(games, (g) -> DateTime.fromISO(g.val.start_clock_time, { zone: g.val.start_timezone }).toISO())

  ctx.ok({ games })
  return
