get          = require 'lodash/get'
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


module.exports = (ctx) ->
  
  sid      = ctx.request.body.season_id
  { c, p } = ctx.request.body

  Game         = await GModel()
  League       = await LModel()
  Season       = await SModel()
  Team         = await TModel()

  if !c
    now = DateTime.local().setZone('utc')
    cgQ = [
      [ 'order-by', 'val.start_utc' ]
      [ 'where',    'meta.deleted',  '==', false ]
      [ 'where',    'rel.season',    '==', sid ]
      [ 'where',    'val.start_utc', '>=', now.minus({ hours: 24 }).toISO() ]
    ]
    cg = await Game.find(cgQ).read()
    c  = cg.meta.id

  gsQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', sid ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'val.start_utc'
      order: 'low-to-high'
    size: 25
 
  [ games, season ] = await (all [
    (Game.page gsQ).read()
    Season.get(sid).read()
  ])

  league = await League.get(season.rel.league).read()
  league = (pick league, [ 'meta.id', 'val.name', 'val.logo_url' ])

  season = (pick season, [ 'meta.id', 'val.name', ])

  games.page.items = await (all (map games.page.items, (_g) ->
    [ away_team, home_team ] = await (all [
      Team.get(_g.rel.away_team).read()
      Team.get(_g.rel.home_team).read()
    ])

    tF = [ 'meta.id', 'val.name', 'rel.division' ]

    away_team = (pick away_team, tF)
    home_team = (pick home_team, tF)

    time = DateTime.fromFormat(((get _g, 'val.start_clock_time') || ''), "yyyy-MM-dd'T'HH:mm:ss", { zone: ((get _g, 'val.start_timezone') || 'utc') })

    g = (merge _g, {
      val:
        home_team: (pick home_team, tF)
        away_team: (pick away_team, tF)
      ui:
        date: if time.isValid then time.toFormat('yyyy.M.d') else null
        time: if time.isValid then time.toFormat('h:mm a')   else null
        zone: if time.isValid then time.toFormat('ZZZZ')     else null
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

  (ctx.ok { games, league, season })
  return

