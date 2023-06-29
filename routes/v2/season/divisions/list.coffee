each         = require 'lodash/each'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
concat       = require 'lodash/concat'
findIndex    = require 'lodash/findIndex'
get          = require 'lodash/get'
set          = require 'lodash/set'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
unionBy      = require 'lodash/unionBy'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'

TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
D2TModel     = require '@/local/models/flame-lib/division-to-team'
DModel       = require '@/local/models/flame-lib/division'


module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, season_id } = ctx.request.body


  D2T      = await D2TModel()
  Division = await DModel()
  Team     = await TModel()
  U2S      = await U2SModel()
  User     = await UModel()

  dsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'select', 'meta.id', 'val.name', ]
    [ 'limit', 1000 ]
  ]

  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
    [ 'select', 'meta.id', 'rel.season', 'val.name', ]
    [ 'limit', 1000]
  ]

  d2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'limit', 1000 ]
  ]
 
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ d2ts, divisions, teams, user ] = await (all [
    (D2T      .list d2tsQ) .read()
    (Division .list dsQ)   .read()
    (Team     .list tQ)    .read()
    (User     .find uQ)    .read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  user_to_season = await (U2S.find u2sQ).read()

  if !user_to_season || !(includes user_to_season.val.roles, 'admin')
    (ctx.badRequest {})
    return

  no_division = { meta: { id: 'none' }, val: { name: 'No Division' }}

  divisions = (sortBy divisions, ((_d) -> (toLower _d.val.name)))
  divisions = (unionBy divisions, [no_division], 'meta.id')

  teams = await (all (map teams, (_t) ->
    d2t  = (find d2ts, { rel: { team: _t.meta.id }})
    team = (merge (pick _t, [ 'meta.id', 'val.name', ]), {
      rel: { division: (get d2t, 'rel.division') ? 'none' }
    })
    return team
  ))
  teams = (sortBy teams, ((_t) -> (toLower _t.val.name)))

  (each teams, (_t) ->
    i  = (findIndex divisions, { meta: { id: _t.rel.division }})
    ts = (concat ((get divisions, "[#{i}].val.teams") ? []), _t)
    (set divisions, "[#{i}].val.teams", ts)
    return
  )

  (ctx.ok { divisions })
  return



