fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
Game         = require '@/local/models/flame/game'
isEmpty      = require 'lodash/isEmpty'
isInteger    = require 'lodash/isInteger'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
SeasonToUser = require '@/local/models/season-to-user'
Standing     = require '@/local/models/flame/standing'
Team         = require '@/local/models/flame/team'
unionBy      = require 'lodash/unionBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { home, away } = ctx.request.body
  game_id = ctx.params.id

  if !isInteger(home) || !isInteger(away)
    ctx.badRequest()
    return

  [ fba, game, user ] = await all([
    fbaI()
    Game.get(game_id)
    User.getByUid(uid)
  ])
  db = fba.firestore()

  if !game
    ctx.badRequest()
    return

  season = { meta: { id: game.rel.season }}
  authorized = await SeasonToUser.anyRole({ season: season, user: user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()
    return

  score = { home, away }
  await db.collection('/games').doc(game.meta.id).update({ 'val-score': score })


  if game.val.start_clock_time > '2022-08-18'
    ctx.ok({})
    return


  P1 = Standing.find([
    [ 'where', 'rel-division', '==', game.rel.division ]
    [ 'where', 'rel-team', '==', game.rel.home_team ]
  ])
  P2 = Standing.find([
    [ 'where', 'rel-division', '==', game.rel.division ]
    [ 'where', 'rel-team', '==', game.rel.away_team ]
  ])
  [ t1_standing, t2_standing ] = await all([ P1, P2 ])

  P3 = ->
    [ home_games, away_games ] = await all([
      Game.list([
        [ 'where', 'rel-division', '==', t1_standing.rel.division ]
        [ 'where', 'rel-home-team', '==', t1_standing.rel.team ]
      ]),
      Game.list([
        [ 'where', 'rel-division', '==', t1_standing.rel.division ]
        [ 'where', 'rel-away-team', '==', t1_standing.rel.team ]
      ])
    ])
    games = unionBy(home_games.page_items, away_games.page_items, 'meta.id')
    games = filter(games, (g) -> g.val.score.home != null)
    return games

  P4 = ->
    [ home_games, away_games ] = await all([
      Game.list([
        [ 'where', 'rel-division', '==', t2_standing.rel.division ]
        [ 'where', 'rel-home-team', '==', t2_standing.rel.team ]
      ]),
      Game.list([
        [ 'where', 'rel-division', '==', t2_standing.rel.division ]
        [ 'where', 'rel-away-team', '==', t2_standing.rel.team ]
      ])
    ])
    games = unionBy(home_games.page_items, away_games.page_items, 'meta.id')
    games = filter(games, (g) -> g.val.score.home != null)
    return games

  [ t1_games, t2_games ] = await all([
    P3()
    P4()
  ])

  t1s = Standing.create().obj()
  t1s = reduce(t1_games, (acc, g) ->
    acc.val.ties += (if (g.val.score.away == g.val.score.home) then 1 else 0)
    acc.val.points += (if (g.val.score.away == g.val.score.home) then 1 else 0)
    if g.rel.home_team == t1_standing.rel.team
      acc.val.goals_against += g.val.score.away
      acc.val.goals_for += g.val.score.home
      acc.val.losses += (if (g.val.score.away > g.val.score.home) then 1 else 0)
      acc.val.points += (if (g.val.score.away < g.val.score.home) then 3 else 0)
      acc.val.wins += (if (g.val.score.away < g.val.score.home) then 1 else 0)
    if g.rel.away_team == t1_standing.rel.team
      acc.val.goals_against += g.val.score.home
      acc.val.goals_for += g.val.score.away
      acc.val.losses += (if (g.val.score.away < g.val.score.home) then 1 else 0)
      acc.val.points += (if (g.val.score.away > g.val.score.home) then 3 else 0)
      acc.val.wins += (if (g.val.score.away > g.val.score.home) then 1 else 0)
    return acc
  , t1s)
  t1s = pick(t1s, [ 'val' ])

  t2s = Standing.create().obj()
  t2s = reduce(t2_games, (acc, g) ->
    acc.val.ties += (if (g.val.score.away == g.val.score.home) then 1 else 0)
    acc.val.points += (if (g.val.score.away == g.val.score.home) then 1 else 0)
    if g.rel.home_team == t2_standing.rel.team
      acc.val.goals_against += g.val.score.away
      acc.val.goals_for += g.val.score.home
      acc.val.losses += (if (g.val.score.away > g.val.score.home) then 1 else 0)
      acc.val.points += (if (g.val.score.away < g.val.score.home) then 3 else 0)
      acc.val.wins += (if (g.val.score.away < g.val.score.home) then 1 else 0)
    if g.rel.away_team == t2_standing.rel.team
      acc.val.goals_against += g.val.score.home
      acc.val.goals_for += g.val.score.away
      acc.val.losses += (if (g.val.score.away < g.val.score.home) then 1 else 0)
      acc.val.points += (if (g.val.score.away > g.val.score.home) then 3 else 0)
      acc.val.wins += (if (g.val.score.away > g.val.score.home) then 1 else 0)
    return acc
  , t2s)
  t2s = pick(t2s, [ 'val' ])

  team_1_standings = Standing.create(merge({ meta: { id: t1_standing.meta.id }}, t1s))
  team_2_standings = Standing.create(merge({ meta: { id: t2_standing.meta.id }}, t2s))

  P5 = ->
    await team_1_standings.update([
      'val.goals_against'
      'val.goals_for'
      'val.losses'
      'val.points'
      'val.ties'
      'val.wins'
    ])
    return

  P6 = ->
    await team_2_standings.update([
      'val.goals_against'
      'val.goals_for'
      'val.losses'
      'val.points'
      'val.ties'
      'val.wins'
    ])
    return

  await all([ P5(), P6() ])

  ctx.ok({})
  return
