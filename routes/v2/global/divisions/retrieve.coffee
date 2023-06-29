each         = require 'lodash/each'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
concat       = require 'lodash/concat'
findIndex    = require 'lodash/findIndex'
get          = require 'lodash/get'
set          = require 'lodash/set'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
{ all }      = require 'rsvp'

D2TModel     = require '@/local/models/flame-lib/division-to-team'
DModel       = require '@/local/models/flame-lib/division'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  sid = ctx.request.body.season_id

  D2T      = await D2TModel()
  Division = await DModel()
  League   = await LModel()
  Season   = await SModel()
  Team     = await TModel()
  User     = await UModel()

  dsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
    [ 'select', 'meta.id', 'val.name', ]
    [ 'limit', 1000 ]
  ]

  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
    [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
    [ 'select', 'meta.id', 'rel.season', 'val.name', ]
    [ 'limit', 1000]
  ]

  d2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
    [ 'limit', 1000 ]
  ]
 
  [ d2ts, divisions, season, teams, ] = await (all [
    (D2T      .list d2tsQ) .read()
    (Division .list dsQ)   .read()
    (Season   .get  sid)   .read()
    (Team     .list tQ)    .read()
  ])

  divisions = (sortBy divisions, ((_d) -> (toLower _d.val.name)))
  
  league = await League.get(season.rel.league).read()
  league = (pick league, [ 'meta.id', 'val.name', 'val.logo_url' ])

  season = (pick season, [ 'meta.id', 'val.name', ])

  teams = await (all (map teams, (_t) ->
    d2t  = (find d2ts, { rel: { team: _t.meta.id }})
    team = (merge (pick _t, [ 'meta.id', 'val.name', ]), {
      rel: { division: (get d2t, 'rel.division') ? 'none' }
    })
    return team
  ))
  teams = (filter teams, (_t) -> (_t.rel.division != 'none'))
  teams = (sortBy teams, ((_t) -> (toLower _t.val.name)))

  (each teams, (_t) ->
    i  = (findIndex divisions, { meta: { id: _t.rel.division }})
    ts = (concat ((get divisions, "[#{i}].val.teams") ? []), _t)
    (set divisions, "[#{i}].val.teams", ts)
    return
  )

  (ctx.ok { divisions, league, season })
  return

