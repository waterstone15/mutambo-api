filter       = require 'lodash/filter'
find         = require 'lodash/find'
compact      = require 'lodash/compact'
flatten      = require 'lodash/flatten'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
intersection = require 'lodash/intersection'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'


module.exports = (ctx) ->
  
  { uid }  = ctx.state.fbUser
  { c, p } = ctx.request.body

  Game         = await GModel()
  # League       = await LModel()
  # Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  # UserToSeason = await U2SModel()
  UserToTeam   = await U2TModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  uF = [ 'meta.id' ]
  user = await User.find(uQ, uF).read()

  u2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    [ 'select', 'meta.id', 'rel.league', 'rel.season', 'rel.team', 'rel.user', 'val.roles' ]
  ]
  u2ts = await UserToTeam.list(u2tsQ).read()

  tids  = (map u2ts, ((_u2t) -> _u2t.rel.team))
  tF    = [ 'meta.id', 'val.name', 'val.statuses' ]
  teams = await Team.getAll(tids, tF).read()
  teams = (filter teams, ((_t) ->
    u2t = (find u2ts, { rel: user: user.meta.id })
    return (
      (includes _t.val.statuses, 'registration-complete') &&
      (!isEmpty (intersection (get u2t, 'val.roles'), [ 'manager', 'player' ]))
    )
  ))
  teams = (map teams, (_t) ->
    u2t = (find u2ts, { rel: team: _t.meta.id })
    return (merge _t, {
      val:
        roles: (intersection (get u2t, 'val.roles'), [ 'manager', 'player' ])
    })
  )

  gF = [
    'meta.id', 'rel.home_team', 'rel.league', 'rel.season', 'rel.away_team',
    'val.score', 'val.start_clock_time', 'val.canceled', 'val.start_utc',
    'val.start_timezone', 'val.location_text', 'ext.gameofficials',
  ]
  
  games = await (all (map teams, (_t) ->
    hgQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.home_team', '==', _t.meta.id ]
      [ 'order-by', 'val.start_utc' ]
      [ 'select', ...gF ]
    ]
    agQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.away_team', '==', _t.meta.id ]
      [ 'order-by', 'val.start_utc' ]
      [ 'select', ...gF ]
    ]

    _hgs = await Game.list(hgQ).read()
    _ags = await Game.list(agQ).read()
    return (flatten [_hgs, _ags])
  ))
  games = (compact (flatten games))


  games = await (all (map games, (_g) ->
    away_team = (find teams, { meta: id: _g.rel.away_team })
    home_team = (find teams, { meta: id: _g.rel.home_team })
    is_manager = (
      (away_team && (includes away_team.val.roles, 'manager')) ||
      (home_team && (includes home_team.val.roles, 'manager'))
    )

    [ away_team, home_team ] = await (all [
      (if !away_team then Team.get(_g.rel.away_team).read() else away_team)
      (if !home_team then Team.get(_g.rel.home_team).read() else home_team)
    ])

    tF = [ 'meta.id', 'val.name', 'rel.division', 'val.roles' ]

    away_team = (pick away_team, tF)
    home_team = (pick home_team, tF)
    clock = ((get _g, 'val.start_clock_time') || '')
    fmt   = "yyyy-MM-dd'T'HH:mm:ss"
    tz    = { zone: ((get _g, 'val.start_timezone') || 'utc') }
    time  = DateTime.fromFormat(clock, fmt, tz)
    now   = DateTime.local().setZone('utc')
    lock  = now.plus({ hours: 48 })

    units = [ 'weeks', 'days', 'hours', 'minutes', 'seconds' ]
    wait = if time then time.diff(lock, units).toObject() else null
    wait_string = switch
      when (wait && (wait.weeks > 0))      then "#{wait.weeks}w"
      when (wait && (wait.days > 1))       then "#{wait.days}d"
      when (wait && (1 >= wait.days > 0))  then "#{wait.days}d #{wait.hours}h"
      when (wait && (wait.hours > 1))      then "#{wait.hours}h"
      when (wait && (1 >= wait.hours > 0)) then "#{wait.hours}h #{wait.minutes}m"
      when (wait && (wait.minutes > 0))    then "#{wait.minutes}m"
      else "<1m"

    g = (merge _g, {
      val:
        away_team:  away_team 
        home_team:  home_team 
        is_manager: is_manager
      ui:
        date: if time.isValid then time.toFormat('yyyy.M.d') else null
        time: if time.isValid then time.toFormat('h:mm a')   else null
        zone: if time.isValid then time.toFormat('ZZZZ')     else null
        gs: (lock >= time)
        gs_wait: if (is_manager && (lock < time)) then wait_string else null
    })
    return g
  ))

  games = (sortBy games, 'val.start_utc')
  # log games

  (ctx.ok { games })
  return



