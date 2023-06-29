_            = require 'lodash'
compact      = require 'lodash/compact'
fetch        = require 'node-fetch'
filter       = require 'lodash/filter'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
intersection = require 'lodash/intersection'
isEmpty      = require 'lodash/isEmpty'
join         = require 'lodash/join'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
template     = require '@/local/templates/game-sheet'
toLower      = require 'lodash/toLower'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
GS           = require '@/local/models/flame-lib/game-sheet'
LModel       = require '@/local/models/flame-lib/league'
MModel       = require '@/local/models/flame-lib/misconduct'
RModel       = require '@/local/models/flame-lib/registration'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->

  { uid }     = ctx.state.fbUser
  { game_id } = ctx.request.body

  Game         = await GModel()
  League       = await LModel()
  Misconduct   = await MModel()
  Registration = await RModel()
  Season       = await SModel()
  Team         = await TModel()
  U2S          = await U2SModel()
  U2T          = await U2TModel()
  User         = await UModel()

  gF = [
    'ext.gameofficials',
    'meta.id',
    'rel.away_team', 'rel.home_team', 'rel.league', 'rel.season',
    'val.canceled', 'val.location_text', 'val.score', 'val.start_clock_time', 'val.start_timezone', 'val.start_utc',
  ]
  game = await Game.get(game_id, gF).read()

  clock = ((get game, 'val.start_clock_time') || '')
  fmt   = "yyyy-MM-dd'T'HH:mm:ss"
  tz    = { zone: ((get game, 'val.start_timezone') || 'utc') }
  time  = DateTime.fromFormat(clock, fmt, tz)
 
  game = (merge game, {
    ui:
      date: if time.isValid then time.toFormat('yyyy.M.d') else null
      time: if time.isValid then time.toFormat('h:mm a')   else null
      zone: if time.isValid then time.toFormat('ZZZZ')     else null
  })

  hu2tsQ = [
    [ 'where', 'meta.deleted', '==', false]
    [ 'where', 'rel.team', '==', game.rel.home_team ]
    [ 'where', 'val.roles', 'array-contains-any', [ 'player', 'manager' ]]
    [ 'select', 'rel.team', 'rel.user', 'val.roles' ]
  ]

  au2tsQ = [
    [ 'where', 'meta.deleted', '==', false]
    [ 'where', 'rel.team', '==', game.rel.away_team ]
    [ 'where', 'val.roles', 'array-contains-any', [ 'player', 'manager' ]]
    [ 'select', 'rel.team', 'rel.user', 'val.roles' ]
  ]

  [ au2ts, away, home, hu2ts, league, season, ] = await (all [
    U2T.list(au2tsQ).read()
    Team.get(game.rel.away_team).read()
    Team.get(game.rel.home_team).read()
    U2T.list(hu2tsQ).read()
    League.get(game.rel.league).read()
    Season.get(game.rel.season).read()
  ])

  away.val.managers = []
  away.val.players = []
  away.val.users = []

  home.val.managers = []
  home.val.players = []
  home.val.users = []

  user_fields = [ 'meta.id', 'val.email', 'val.full_name' ]

  u2tToUser = (_u2t) ->
    mQ = [
      [ 'where', 'meta.v',     '==', '00000.00000.00000' ]
      [ 'where', 'rel.user',   '==', _u2t.rel.user ]
      [ 'where', 'val.status', '==', 'suspended' ]
      [ 'select', 'meta.id' ,  'rel.user', 'val.scopes' ]
    ]
    rQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.team',     '==', _u2t.rel.team ]
      [ 'where', 'rel.user',     '==', _u2t.rel.user ]
      [ 'where', 'val.status',   '==', 'complete' ]
    ]
    rF = [ 'meta.created_at' , 'meta.updated_at', ]
    [ _ms, _r, _u ] = await (all [
      Misconduct   .list(mQ)           .read()
      Registration .find(rQ, rF)       .read()
      User         .get(_u2t.rel.user) .read()
    ])
    
    _scopes = [
      "league:#{league.meta.id}"
      "season:#{season.meta.id}"
      "team:#{_u2t.rel.team}"
    ]
    _ms = (filter _ms, ((_m) -> !(isEmpty (intersection _scopes, _m.val.scopes ))))

    rtime = DateTime.fromISO(_r.meta.created_at)
    lock  = if time.isValid then (time.minus { hours: 48 }) else null

    if !(isEmpty _ms)
      return (merge (pick _u, user_fields), (pick _u2t, [ 'val.roles' ]), { val: suspended: true })
    else if ((includes _u2t.val.roles, 'player') && time.isValid && (lock < rtime))
      return (merge (pick _u, user_fields), (pick _u2t, [ 'val.roles' ]), { val: late: true })
    else
      return (merge (pick _u, user_fields), (pick _u2t, [ 'val.roles' ]))

  home.val.users = await (all (map hu2ts, u2tToUser))
  home.val.users = (compact home.val.users)
  home.val.users = (sortBy home.val.users, ((_u) -> "#{(toLower _u.val.full_name)}-#{(toLower _u.val.display_name)}"))

  away.val.users = await (all (map au2ts, u2tToUser))
  away.val.users = (compact away.val.users)
  away.val.users = (sortBy away.val.users, ((_u) -> "#{(toLower _u.val.full_name)}-#{(toLower _u.val.display_name)}"))
  
  away.val.managers = (filter away.val.users, (_u) -> (includes _u.val.roles, 'manager' ))
  away.val.players  = (filter away.val.users, (_u) -> (includes _u.val.roles, 'player' ))

  home.val.managers = (filter home.val.users, (_u) -> (includes _u.val.roles, 'manager' ))
  home.val.players  = (filter home.val.users, (_u) -> (includes _u.val.roles, 'player' ))

  sheet =
    away: away
    game: game
    home: home
    league: league
    season: season
    
  (ctx.ok { sheet })
  return
