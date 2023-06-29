_            = require 'lodash'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
startCase    = require 'lodash/startCase'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
uniq         = require 'lodash/uniq'
uniqBy       = require 'lodash/uniqBy'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

LModel       = require '@/local/models/flame-lib/league'
MModel       = require '@/local/models/flame-lib/misconduct'
PModel       = require '@/local/models/flame-lib/payment'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, season_id } = ctx.request.body

  League       = await LModel()
  Misconduct   = await MModel()
  Payment      = await PModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  U2S          = await U2SModel()
  UserToTeam   = await U2TModel()

 
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ season, user ] = await (all [
    Season .get(season_id) .read()
    User   .find(uQ)       .read()
  ])
  league = await League.get(season.rel.league).read()

  mQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'meta.v',       '==', '00000.00000.00000' ]
      [ 'where', 'rel.league',   '==', season.rel.league ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 25

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ misconducts, u2s ] = await (all [
    Misconduct .page(mQ)   .read()
    U2S        .find(u2sQ) .read()
  ])

  if !u2s || !(includes u2s.val.roles, 'admin')
    (ctx.badRequest {})
    return

  scopes = (reduce misconducts.page.items, ((_acc, _m) ->
    return (uniq (union _acc, _m.val.scopes))
  ), [])
  
  leagues = []
  seasons = []
  teams   = []
  await (all (map scopes, (_s) ->
    if /^league:/.test(_s)
      id = _s.match(/^league:(?<id>.+)/).groups.id
      l  = await League.get(id, [ 'meta.id', 'val.name' ]).read()
      leagues.push(l)
    
    if /^season:/.test(_s)
      id = _s.match(/^season:(?<id>.+)/).groups.id
      s  = await Season.get(id, [ 'meta.id', 'val.name' ]).read()
      seasons.push(s)
    
    if /^team:/.test(_s)
      id = _s.match(/^team:(?<id>.+)/).groups.id
      t  = await Team.get(id, [ 'meta.id', 'val.name' ]).read()
      teams.push(t)

    return null
  ))

  misconducts.page.items = await (all (map misconducts.page.items, (_m) ->
    start = DateTime.fromISO((get _m, 'val.suspension_start_utc') || '').setZone('utc')
    end   = DateTime.fromISO((get _m, 'val.suspension_end_utc') || '').setZone('utc')

    scope_leagues = _(_m.val.scopes)
      .filter((_s) -> (/^league:/.test _s))
      .map((_s) -> _s.match(/^league:(?<id>.+)/).groups.id)
      .map((_id) -> (find leagues, { meta: id: _id }).val.name)
      .value().join(', ')

    scope_seasons = _(_m.val.scopes)
      .filter((_s) -> (/^season:/.test _s))
      .map((_s) -> _s.match(/^season:(?<id>.+)/).groups.id)
      .map((_id) -> (find seasons, { meta: id: _id }).val.name)
      .value().join(', ')

    scope_teams = _(_m.val.scopes)
      .filter((_s) -> (/^team:/.test _s))
      .map((_s) -> _s.match(/^team:(?<id>.+)/).groups.id)
      .map((_id) -> (find teams, { meta: id: _id }).val.name)
      .value().join(', ')

    pF = [ 'meta.id', 'val.code', 'val.currency', 'val.status', 'val.total', ]

    [ _payment, _user ] = await (all [
      (if _m.rel.payment then Payment.get(_m.rel.payment, pF).read() else null)
      User.get(_m.rel.user, [ 'meta.id', 'val.full_name' ]).read()
    ])

    m = (merge _m, {
      val:
        payment: _payment
        user:    _user
      ui:
        status: (startCase _m.val.status)
        end_date:      if end.isValid     then (end.toFormat 'yyyy.M.d')   else null
        end_time:      if end.isValid     then (end.toFormat 'h:mm a')     else null
        end_zone:      if end.isValid     then (end.toFormat 'ZZZZ')       else null
        scope_leagues: if !!scope_leagues then scope_leagues               else null
        scope_seasons: if !!scope_seasons then scope_seasons               else null
        scope_teams:   if !!scope_teams   then scope_teams                 else null
        start_date:    if start.isValid   then (start.toFormat 'yyyy.M.d') else null
        start_time:    if start.isValid   then (start.toFormat 'h:mm a')   else null
        start_zone:    if start.isValid   then (start.toFormat 'ZZZZ')     else null
    })
    return m
  ))

  (ctx.ok { misconducts })
  return



