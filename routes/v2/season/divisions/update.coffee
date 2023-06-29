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


  D2T      = await DModel()
  Division = await DModel()
  Team     = await TModel()
  U2S      = await U2SModel()
  User     = await UModel()

  dQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', season_id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    fields: [ 'meta.id', 'val.name', ]
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 200

  tQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', season_id ]
      [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    fields: [ 'meta.id', 'rel.season', 'val.name', ]
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 1000

  d2tQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', season_id ]
      [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 1000
 
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ divisions, teams, user ] = await (all [
    (Division.page dQ).read()
    (Team.page tQ)    .read()
    (User.find uQ)    .read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  user_to_season = await (U2S.find u2sQ).read()

  if !user_to_season || !(includes user_to_season.val.roles, 'admin')
    (ctx.badRequest {})
    return

  divisions.page.items = (sortBy divisions.page.items, 'val.name')
  divisions.page.items = (unionBy divisions.page.items, [{ meta: { id: 'none' }, val: { name: 'No Division' }}], 'meta.id')

  teams = await (all (map teams.page.items, (_t) ->
    d2tQ2 = [
      [ 'where', 'rel.team',   '==', _t.meta.id ]
      [ 'where', 'rel.season', '==', season_id ]
    ]
    d2t = await D2T.find(d2tQ2).read()
    return (merge (pick _t, [ 'meta.id', 'val.name', ]), {
      rel:
        division: (get d2t, 'meta.id') ? 'none'
    })
  ))
  teams = (sortBy teams, 'val.name')

  (each teams, (_t) ->
    i  = (findIndex divisions.page.items, { meta: { id: _t.rel.division }})
    ts = (concat ((get divisions, "page.items[#{i}].val.teams") ? []), _t)
    (set divisions, "page.items[#{i}].val.teams", ts)
    return
  )

  log divisions

  (ctx.ok { divisions })
  return



