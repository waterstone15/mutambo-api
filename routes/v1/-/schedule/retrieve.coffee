fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
first        = require 'lodash/first'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
last         = require 'lodash/last'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reverse      = require 'lodash/reverse'
sortBy       = require 'lodash/sortBy'
truncate     = require 'lodash/truncate'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { end_before, search_at, season_id, start_after } = ctx.request.body

  [ fba, season ] = await all([
    fbaI()
    fbaH.get('/seasons', season_id)
  ])
  db = fba.firestore()

  if !season
    ctx.badRequest()
    return

  game_fields = [
    'ext.gameofficials'
    'meta.id'
    'rel.home_team'
    'rel.division'
    'rel.away_team'
    'val.canceled'
    'val.location_text'
    'val.score'
    'val.start_clock_time'
    'val.start_timezone'
  ]

  [ last_game, first_game, league ] = await all([
    fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'desc' ]]})
    fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'asc' ]]})
    fbaH.get('/leagues', season.rel.league)
  ])

  if !search_at && !start_after && !end_before
    search_at = DateTime.local().setZone('utc').startOf('day').minus({ hours: 36 }).toFormat('yyyy-MM-dd')
    if last_game.val.start_clock_time < search_at
      search_at = DateTime.fromISO(last_game.val.start_clock_time).setZone('utc').startOf('day').minus({ hours: 36}).toFormat('yyyy-MM-dd')

  q =
    endBefore: end_before
    filters: [[ 'rel-season', '==', season.meta.id ]]
    limit: 40
    orderBy: [[ 'val-start-clock-time', "#{if !isEmpty(end_before) then 'desc' else 'asc'}" ]]
    searchAt: search_at
    startAfter: start_after
  games = await fbaH.findAll('/games', q)

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
    game = pick(game, game_fields)
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

  league = pick(league, [ 'meta.id', 'val.name', 'val.logo_url' ])
  season = pick(season, [ 'meta.id', 'val.name' ])

  obj =
    league: league
    season: season
    end: pick(last(games), game_fields)
    first: pick(first_game, game_fields)
    last: pick(last_game, game_fields)
    games: games
    start: pick(first(games), game_fields)

  ctx.ok(obj)
  return
