fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
union        = require 'lodash/union'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { game_id } = ctx.request.body

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: ['id'] })
  ])
  db = fba.firestore()

  game = await fbaH.get('/games', game_id)

  [ away_team, division, home_team, league, season, a_rolesDS, h_rolesDS, a_managersQS, h_managersQS ] = await all([
    fbaH.get('/teams', game.rel.away_team)
    fbaH.get('/divisions', game.rel.division)
    fbaH.get('/teams', game.rel.home_team)
    fbaH.get('/leagues', game.rel.league)
    fbaH.get('/seasons', game.rel.season)
    db.collection("/teams/#{game.rel.away_team}/users").doc(user.meta.id).get()
    db.collection("/teams/#{game.rel.home_team}/users").doc(user.meta.id).get()
    db.collection("/teams/#{game.rel.away_team}/users").where('access-control', 'array-contains-any', ['captain', 'manager']).get()
    db.collection("/teams/#{game.rel.home_team}/users").where('access-control', 'array-contains-any', ['captain', 'manager']).get()

  ])

  a_roles = if a_rolesDS.exists then a_rolesDS.data()['access-control'] else []
  h_roles = if h_rolesDS.exists then h_rolesDS.data()['access-control'] else []
  roles = map(union(a_roles, h_roles), (r) -> if (r == 'captain') then 'manager' else r)

  if isEmpty(roles)
    ctx.unauthorized()
    return

  game = pick(game, [
    'ext.gameofficials'
    'meta.id'
    'rel'
    'val'
  ])

  game_moment = DateTime.fromISO(game.val.start_clock_time, { zone: game.val.start_timezone })
  now_locale  = DateTime.local().setZone(game.val.start_timezone)

  game_near   = now_locale.minus({ hours: 48 }) < game_moment
  game_recent = now_locale.plus({ hours: 48 }) > game_moment

  game = merge(game, {
    val:
      away_team: pick(away_team, [ 'meta.id', 'val.name', 'val.manager_count', 'val.player_count' ])
      division:  pick(division, [ 'meta.id', 'val.name' ])
      home_team: pick(home_team, [ 'meta.id', 'val.name', 'val.manager_count', 'val.player_count' ])
      league:    pick(league, [ 'meta.id', 'val.name', 'val.logo_url' ])
      roles:     roles
      isManager: includes(roles, 'manager')
      season:    pick(season, [ 'meta.id', 'val.name' ])
    ui:
      can_print_roster: includes(roles, 'manager') && (game_near || game_recent)
      date_formatted: game_moment.toFormat('MMMM d, yyyy')
      time_formatted: game_moment.toFormat('h:mm a ZZZZ')
  })

  if includes(roles, 'manager')
    away_managers = await all(map(a_managersQS.docs, (DS) ->
      manager = await User.get(DS.id, { values: { meta: ['id'], val: [ 'display-name', 'email' ] }})
      return manager
    ))
    home_managers = await all(map(h_managersQS.docs, (DS) ->
      manager = await User.get(DS.id, { values: { meta: ['id'], val: [ 'display-name', 'email' ] }})
      return manager
    ))
    game = merge(game, {
      val:
        home_managers: home_managers
        away_managers: away_managers
    })

  ctx.ok({ game })
  return












