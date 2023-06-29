get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
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
  
  { uid }             = ctx.state.fbUser
  { c, p, season_id } = ctx.request.body

  Game         = await GModel()
  League       = await LModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToSeason = await U2SModel()
  UserToTeam   = await U2TModel()

  if !c
    now = DateTime.local().setZone('utc')
    cgQ = [
      [ 'order-by', 'val.start_utc' ]
      [ 'where',    'meta.deleted',  '==', false ]
      [ 'where',    'rel.season',    '==', season_id ]
      [ 'where',    'val.start_utc', '>=', now.minus({ hours: 24 }).toISO() ]
    ]
    cg = await Game.find(cgQ).read()
    c  = cg.meta.id

  gsQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', season_id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'val.start_utc'
      order: 'low-to-high'
    size: 25
 
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
 
  [ games, user ] = await (all [
    (Game.page gsQ).read()
    (User.find uQ).read()
  ])

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2s = await (UserToSeason.find u2sQ).read()

  if !u2s
    (ctx.badRequest {})
    return

  games.page.items = await (all (map games.page.items, (_g) ->
    [ away_team, home_team ] = await (all [
      Team.get(_g.rel.away_team).read()
      Team.get(_g.rel.home_team).read()
    ])

    tF = [ 'meta.id', 'val.name', 'rel.division' ]

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
        home_team: (pick home_team, tF)
        away_team: (pick away_team, tF)
      ui:
        date: if time.isValid then time.toFormat('yyyy.M.d') else null
        time: if time.isValid then time.toFormat('h:mm a')   else null
        zone: if time.isValid then time.toFormat('ZZZZ')     else null
        gs: (lock >= time)
        gs_wait: if (lock < time) then wait_string else null
    })

    return (pick g, [
      'ext'
      'meta'
      'rel'
      'ui'
      'val'
    ])
    return g
  ))

  (ctx.ok { games })
  return



