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
SeasonToUser = require '@/local/models/season-to-user'
sortBy       = require 'lodash/sortBy'
truncate     = require 'lodash/truncate'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { end_before, search_at, season_id, start_after, } = ctx.request.body

  [ fba, season, user ] = await all([
    fbaI()
    fbaH.get('/seasons', season_id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  authorized = await SeasonToUser.anyRole({ season, user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()
    return

  if !season || !user
    ctx.badRequest()
    return

  [ last_game, first_game ] = await all([
    fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'desc' ]]})
    fbaH.findOne('/games', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-start-clock-time', 'asc' ]]})
  ])

  if !search_at && !start_after && !end_before
    search_at = DateTime.local().setZone('utc').startOf('day').minus({ hours: 36 }).toFormat('yyyy-MM-dd')
    if last_game.val.start_clock_time < search_at
      search_at = DateTime.fromISO(last_game.val.start_clock_time).setZone('utc').startOf('day').minus({ hours: 36}).toFormat('yyyy-MM-dd')

  q =
    endBefore: end_before
    filters: [[ 'rel-season', '==', season.meta.id ]]
    limit: 20
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
  await all([ gamesPs ])

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

  ctx.ok({
    end: last(games)
    first: first_game
    last: last_game
    games: games
    start: first(games)
  })
  return


