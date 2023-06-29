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
stripeI      = require('stripe')
truncate     = require('lodash/truncate')
union        = require('lodash/union')
unionBy      = require('lodash/unionBy')
User         = require('@/local/models/user')
Vault        = require('@/local/lib/arctic-vault')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')


module.exports = (ctx) ->
  vault = await Vault.open()

  stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)

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

  first_game = await fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'asc' ]]})
  last_game  = await fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'desc' ]]})
  # console.log first_game
  # console.log last_game

  opts = {
    filters: [[ 'rel-season', '==', season.meta.id ]]
    # limit: 10
  }
  games = await fbaH.findAll('/games', opts)

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
      teams[game.rel.away_team] = await fbaH.get('/teams', game.rel.away_team, { fields: [ 'meta-id', 'val-name' ] })

    if !teams[game.rel.home_team]
      teams[game.rel.home_team] = {}
      teams[game.rel.home_team] = await fbaH.get('/teams', game.rel.home_team, { fields: [ 'meta-id', 'val-name' ] })
  ))

  await all([ divisionsPs, gamesPs ])

  games = map(games, (game) ->
    game = merge(game, {
      ui:
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


