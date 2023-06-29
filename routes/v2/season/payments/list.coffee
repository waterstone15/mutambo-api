filter       = require 'lodash/filter'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
isNumber     = require 'lodash/isNumber'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
stripeI      = require 'stripe'
uniq         = require 'lodash/uniq'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
PModel       = require '@/local/models/flame-lib/payment'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, season_id } = ctx.request.body

  League       = await LModel()
  Payment      = await PModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToSeason = await U2SModel()

  pQ =
    constraints: [
      [ 'where', 'meta.created_at', '>=', '2023-01' ]
      [ 'where', 'rel.season', '==', season_id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 20
 
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ payments, user ] = await (all [
    (Payment.page pQ).read()
    (User.find uQ).read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  user_to_season = await (UserToSeason.find u2sQ).read()

  if !user_to_season || !(includes user_to_season.val.roles, 'admin')
    (ctx.badRequest {})
    return

  l_ids = (filter (uniq (map payments.page.items, (_p) -> _p.rel.league)))
  u_ids = (filter (uniq (map payments.page.items, (_p) -> _p.rel.user)))
  s_ids = (filter (uniq (map payments.page.items, (_p) -> _p.rel.season)))
  t_ids = (filter (uniq (map payments.page.items, (_p) -> _p.rel.team)))

  [ leagues, seasons, teams, users, ] = await all([
    (League .getAll l_ids).read()
    (Season .getAll s_ids).read()
    (Team   .getAll t_ids).read()
    (User   .getAll u_ids).read()
  ])

  payments.page.items = (map payments.page.items, (_p) ->
    asignee    = (find users,    { meta: { id: _p.rel.user }})
    league     = (find leagues,  { meta: { id: _p.rel.league }})
    payer      = (find users,    { meta: { id: _p.rel.payer }})
    payment    = (find payments, { meta: { id: _p.rel.payment }})
    season     = (find seasons,  { meta: { id: _p.rel.season }})
    team       = (find teams,    { meta: { id: _p.rel.team }})

    pmt = (merge _p, {
      val:
        asignee: (pick asignee, [ 'val.full_name', 'val.email' ])
        league:  (pick league,  [ 'val.name' ])
        payer:   (pick payer,   [ 'val.full_name', 'val.email' ])
        season:  (pick season,  [ 'val.name' ])
        team:    (pick team,    [ 'val.name' ])
    })

    return (pick pmt, [
      'meta.id', 'meta.created_at', 'meta.type'
      'val.form.team_name', 'val.form.team_notes', 
      'val.code', 'val.currency', 'val.description', 'val.status', 'val.total',
      'val.assignee',  'val.league', 'val.payer', 'val.season', 'val.team', 
    ])
  )

  ctx.ok({ payments: payments })
  return



