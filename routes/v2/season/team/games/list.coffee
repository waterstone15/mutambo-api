find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
reduce       = require 'lodash/reduce'
sortBy       = require 'lodash/sortBy'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  { uid }       = ctx.state.fbUser
  { season_id } = ctx.request.body
  { team_id }   = ctx.request.body

  Game = await GModel()
  Team = await TModel()
  U2S  = await U2SModel()
  U2T  = await U2TModel()
  User = await UModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ, [ 'meta.id' ]).read()

  if !user
    (ctx.badRequest {})
    return

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]

  gF = [
    'meta.id',
    'rel.away_team',
    'rel.home_team',
    'val.start_clock_time',
    'val.start_timezone',
    'val.start_utc'
  ]

  agsQ = [
    [ 'where', 'meta.deleted',  '==', false ]
    [ 'where', 'rel.away_team', '==', team_id ]
    [ 'where', 'val.canceled',  '==', false ]
    [ 'select', ...gF]
  ]
  hgsQ = [
    [ 'where', 'meta.deleted',  '==', false ]
    [ 'where', 'rel.home_team', '==', team_id ]
    [ 'where', 'val.canceled',  '==', false ]
    [ 'select', ...gF]
  ]

  u2sF = [ 'meta.id', 'val.roles' ]

  [ u2s, ags, hgs ] = await (all [
    U2S  .find(u2sQ, u2sF) .read()
    Game .list(agsQ)       .read()
    Game .list(hgsQ)       .read()
  ])

  games = (union ags, hgs)
  tids  = (reduce games, (_acc, _g) ->
    return (union _acc, [ _g.rel.home_team, _g.rel.away_team ])
  , [])
  tF = [ 'meta.id', 'val.name']
  teams = await Team.getAll(tids, tF).read()

  games = (map games, (_g) ->
    clock = ((get _g, 'val.start_clock_time') || '')
    fmt   = "yyyy-MM-dd'T'HH:mm:ss"
    tz    = { zone: ((get _g, 'val.start_timezone') || 'utc') }
    time  = DateTime.fromFormat(clock, fmt, tz)

    return (merge _g, {
      val:
        away_team: (find teams, { meta: id: _g.rel.away_team })
        home_team: (find teams, { meta: id: _g.rel.home_team })
      ui:
        date: if time.isValid then time.toFormat('yyyy-MM-dd') else null
        time: if time.isValid then time.toFormat('h:mm a')   else null
        zone: if time.isValid then time.toFormat('ZZZZ')     else null
    })
  )
  games = (sortBy games, [ 'val.start_utc' ])

  if !u2s
    (ctx.badRequest {})
    return

  (ctx.ok { games })
  return
