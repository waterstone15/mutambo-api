convert      = require('@/local/lib/convert')
difference   = require('lodash/difference')
fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
includes     = require('lodash/includes')
intersection = require('lodash/intersection')
isEmpty      = require('lodash/isEmpty')
isObject     = require('lodash/isObject')
map          = require('lodash/map')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
sortBy       = require('lodash/sortBy')
union        = require('lodash/union')
unionBy      = require('lodash/unionBy')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')


module.exports = (ctx) ->

  fba = await fbaInit()
  db = fba.firestore()

  { season_id } = ctx.query
  cache_id = await convert.toHashedBase32("#{season_id}-games-public")

  league = {}
  games = []
  season = {}

  [ cacheDS, seasonDS ] = await all([
    db.collection('/request-caches').doc(cache_id).get()
    db.collection('/seasons').doc(season_id).get()
  ])

  if !seasonDS.exists
    ctx.badRequest()
    return

  if cacheDS.exists && cacheDS.data().valid == true
    { league, games, season } = JSON.parse(cacheDS.data().data)
    ctx.ok({ league, games, season })
    return

  season = pick(fbaHelpers.deserialize(seasonDS.data()), [ 'meta.id', 'val.name', 'rel.league' ])

  leagueDS = await db.collection('/leagues').doc(season.rel.league).get()

  if !leagueDS.exists
    ctx.badRequest()
    return

  league = pick(fbaHelpers.deserialize(leagueDS.data()), [ 'meta.id', 'val.name', 'val.logo_url', ])

  gamesQS = await db.collection('/games').where('rel-season', '==', season.meta.id).get()

  games = await all(map(gamesQS.docs, (gameDS) ->
    return if (!gameDS.exists || gameDS.data()['-deleted'] == true)

    game = fbaHelpers.deserialize(gameDS.data())

    [ homeTeamDS, awayTeamDS, divisionDS,  ] = await all([
      db.collection('/teams').doc(game.rel.home_team).get()
      db.collection('/teams').doc(game.rel.away_team).get()
      if game.rel.division then db.collection('/divisions').doc(game.rel.division).get() else Promise.resolve({ exists: false })
    ])

    if divisionDS.exists
      game.rel.division =
        meta: { id: divisionDS.id }
        val: { name: divisionDS.data()['val-name'] }

    game.rel.home_team =
      meta: { id: homeTeamDS.id }
      val: { name: homeTeamDS.data()['name']}

    game.rel.away_team =
      meta: { id: awayTeamDS.id }
      val: { name: awayTeamDS.data()['name']}

    return game
  ))
  games = filter(games, isObject)

  await db.collection('/request-caches').doc(cache_id).set({
    valid: true
    data: JSON.stringify({ league, games, season })
  })

  ctx.ok({ league, games, season })
  return
