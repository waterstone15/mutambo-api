filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isNumber     = require 'lodash/isNumber'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
set          = require 'lodash/set'
stripeI      = require 'stripe'
uniq         = require 'lodash/uniq'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
PModel       = require '@/local/models/flame-lib/payment'
RModel       = require '@/local/models/flame-lib/registration'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, fs, season_id } = ctx.request.body

  vault  = await Vault.open()
  stripe = (stripeI vault.secrets.kv.STRIPE_SECRET_KEY)

  League       = await LModel()
  Payment      = await PModel()
  Registration = await RModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToSeason = await U2SModel()

  types = [ 'registration/season-team', 'registration/team-player', 'registration/team-manager' ]
  type_ok = (includes types, (get fs, 'type'))

  rQ =
    constraints: [
      [ 'where', 'meta.deleted',    '==', false ],
      [ 'where', 'meta.updated_at', '>=', '2023-01' ],
      [ 'where', 'rel.season',      '==', season_id ],
      ...(if type_ok then [[ 'where', 'meta.type', '==', fs.type ]] else [])
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'meta.updated_at'
      order: 'high-to-low'
    size: 25

    
 
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ registrations, user ] = await (all [
    Registration.page(rQ).read()
    User.find(uQ).read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  user_to_season = await (UserToSeason.find u2sQ).read()

  if !user_to_season || !(includes user_to_season.val.roles, 'admin')
    ctx.badRequest({})
    return

  l_ids = (filter (uniq (map registrations.page.items, (_r) -> _r.rel.league)))
  p_ids = (filter (uniq (map registrations.page.items, (_r) -> _r.rel.payment)))
  r_ids = (filter (uniq (map registrations.page.items, (_r) -> _r.rel.user)))
  s_ids = (filter (uniq (map registrations.page.items, (_r) -> _r.rel.season)))
  t_ids = (filter (uniq (map registrations.page.items, (_r) -> _r.rel.team)))

  [ leagues, payments, registrants, seasons, teams, ] = await all([
    (League .getAll l_ids).read()
    (Payment.getAll p_ids).read()
    (User   .getAll r_ids).read()
    (Season .getAll s_ids).read()
    (Team   .getAll t_ids).read()
  ])

  payments = (map payments, (_p) ->
    if (isNumber _p.val.total)
      return _p
    else
      return (merge _p, {
        val:
          currency: _p.val.payment_currency
          total:    _p.val.payment_total
      })
  )

  registrations.page.items = (map registrations.page.items, (_r) ->
    league     = (find leagues,     { meta: { id: _r.rel.league }})
    payment    = (find payments,    { meta: { id: _r.rel.payment }})
    registrant = (find registrants, { meta: { id: _r.rel.user }})
    season     = (find seasons,     { meta: { id: _r.rel.season }})
    team       = (find teams,       { meta: { id: _r.rel.team }})

    r = (merge _r, {
      val:
        league:     (pick league,     [ 'val.name' ])
        payment:    (pick payment,    [ 'val.code', 'val.status', 'val.currency', 'val.total', ])
        registrant: (pick registrant, [ 'val.email', 'val.full_name' ])
        season:     (pick season,     [ 'val.name' ])
        team:       (pick team,       [ 'val.name' ])
    })

    return (pick r, [
      'meta.id', 'meta.updated_at', 'meta.type'
      'val.form.team_name', 'val.form.team_notes',
      'val.league', 'val.payment', 'val.registrant', 'val.season', 'val.status', 'val.team',
    ])
  )

  ctx.ok({ registrations })
  return



