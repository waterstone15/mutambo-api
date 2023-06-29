filter       = require 'lodash/filter'
find         = require 'lodash/find'
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
RModel       = require '@/local/models/flame-lib/registration'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->
  vault = await Vault.open()

  stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)

  League       = await LModel()
  Payment      = await PModel()
  Registration = await RModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()

  { uid } = ctx.state.fbUser
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
  user = await User.find(uQ).read()

  rQ =
    constraints: [
      [ 'where', 'meta.deleted',    '==', false ]
      [ 'where', 'meta.updated_at', '>=', '2023-01' ]
      [ 'where', 'rel.user',        '==', user.meta.id ]
    ]
    sort:
      field: 'meta.updated_at'
      order: 'high-to-low'
    size: 100

  registrations = await Registration.page(rQ).read()

  league_ids  = filter(uniq(map(registrations.page.items, (_r) -> _r.rel.league)))
  payment_ids = filter(uniq(map(registrations.page.items, (_r) -> _r.rel.payment)))
  season_ids  = filter(uniq(map(registrations.page.items, (_r) -> _r.rel.season)))
  team_ids    = filter(uniq(map(registrations.page.items, (_r) -> _r.rel.team)))

  [ leagues, payments, seasons, teams, ] = await all([
    League.getAll(league_ids).read()
    Payment.getAll(payment_ids).read()
    Season.getAll(season_ids).read()
    Team.getAll(team_ids).read()
  ])

  payments = map(payments, (_p) ->
    if isNumber(_p.val.total)
      return _p
    else
      return merge(_p, {
        val:
          currency: _p.val.payment_currency
          total: _p.val.payment_total
      })
  )

  registrations.page.items = map(registrations.page.items, (_r) ->
    league  = find(leagues,  { meta: { id: _r.rel.league }})
    payment = find(payments, { meta: { id: _r.rel.payment }})
    season  = find(seasons,  { meta: { id: _r.rel.season }})
    team    = find(teams,    { meta: { id: _r.rel.team }})

    r = merge(_r, {
      val:
        league:  pick(league,  [ 'val.name' ])
        season:  pick(season,  [ 'val.name' ])
        team:    pick(team,    [ 'val.name' ])
        payment: pick(payment, [ 'val.code', 'val.status', 'val.currency', 'val.total', ])
    })

    return pick(r, [
      'meta.id', 'meta.updated_at', 'meta.type'
      'val.league', 'val.season', 'val.team', 'val.payment'
    ])
  )

  ctx.ok({ registrations })
  return



