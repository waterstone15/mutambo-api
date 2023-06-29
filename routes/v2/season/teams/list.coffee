filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'

D2TModel     = require '@/local/models/flame-lib/division-to-team'
DModel       = require '@/local/models/flame-lib/division'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, season_id } = ctx.request.body

  Division     = await DModel()
  D2T          = await D2TModel()
  League       = await LModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  U2S          = await U2SModel()
  UserToTeam   = await U2TModel()

  tQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season',   '==', season_id ]
      [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    fields: [ 
      'meta.id', 'meta.updated_at', 'meta.type',
      'rel.division', 'rel.league', 'rel.season',
      'val.name',
    ]
    sort:
      field: 'val.name'
      order: 'low-to-high'
    size: 100
 
  d2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id]
    [ 'select', 'meta.id', 'rel.division', 'rel.season', 'rel.team', ]
  ]
  dQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id]
    [ 'select', 'meta.id', 'val.name' ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  uF = [ 'meta.id' ]
 
  [ d2ts, divisions, teams, user ] = await (all [
    D2T      .list(d2tsQ)  .read()
    Division .list(dQ)     .read()
    Team     .page(tQ)     .read()
    User     .find(uQ, uF) .read()
  ])

  if !user
    (ctx.badRequest {})
    return

  l_ids = (filter (uniq (map teams.page.items, (_t) -> _t.rel.league)))
  s_ids = (filter (uniq (map teams.page.items, (_t) -> _t.rel.season)))

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]

  [ leagues, seasons, u2s ] = await (all [
    League .getAll(l_ids) .read()
    Season .getAll(s_ids) .read()
    U2S    .find(u2sQ)    .read()
  ])

  if !u2s
    (ctx.badRequest {})
    return

  teams.page.items = await (all (map teams.page.items, (_t) ->
    league = (find leagues, { meta: { id: _t.rel.league }})
    season = (find seasons, { meta: { id: _t.rel.season }})

    mcQ = [
      [ 'where', 'rel.team', '==', _t.meta.id ]
      [ 'where', 'val.roles', 'array-contains', 'manager' ]
    ]
    pcQ = [
      [ 'where', 'rel.team', '==', _t.meta.id ]
      [ 'where', 'val.roles', 'array-contains', 'player' ]
    ]
    [ mc, pc ] = await (all [
      (UserToTeam.count mcQ).read()
      (UserToTeam.count pcQ).read()
    ])

    _d2t      = (find d2ts, { rel: team: _t.meta.id })
    _division = (find divisions, { meta: id: _d2t?.rel?.division })

    t = (merge _t, {
      val:
        division:      _division
        league:        (pick league, [ 'val.name' ])
        manager_count: (mc ? 0)
        player_count:  (pc ? 0)
        season:        (pick season, [ 'val.name' ])
    })

    return (pick t, [
      'meta.id', 'meta.updated_at', 'meta.type'
      'val.division', 'val.name',  'val.league',
      'val.manager_count', 'val.player_count', 'val.season',
    ])
  ))

  (ctx.ok { teams })
  return



