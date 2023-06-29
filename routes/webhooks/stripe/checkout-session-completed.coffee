any          = require 'lodash/some'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
stripeI      = require 'stripe'
Team         = require '@/local/models/team'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
Vault        = require '@/local/lib/arctic-vault'
{ DateTime } = require 'luxon'

PModel   = require '@/local/models/flame-lib/payment'
RModel   = require '@/local/models/flame-lib/registration'
TModel   = require '@/local/models/flame-lib/team'
U2LModel = require '@/local/models/flame-lib/user-to-league'
U2SModel = require '@/local/models/flame-lib/user-to-season'
U2TModel = require '@/local/models/flame-lib/user-to-team'
UModel   = require '@/local/models/flame-lib/user'


ite = (c, a, b = null) -> if c then a else b

fn = (ctx) ->
  vault   = await Vault.open()
  stripe  = (stripeI vault.secrets.kv.STRIPE_SECRET_KEY)
  
  Flame   = await (FLI 'main')

  Payment        = await PModel()
  Registration   = await RModel()
  Team           = await TModel()
  User           = await UModel()
  UserToLeague   = await U2LModel()
  UserToSeason   = await U2SModel()
  UserToTeam     = await U2TModel()

  try
    sig  = ctx.request.headers['stripe-signature']
    args = [ ctx.request.rawBody, sig, vault.secrets.kv.STRIPE_WEBHOOK_SECRET_1 ]
    (stripe.webhooks.constructEvent ...args)
  catch err
    ctx.unauthorized({})
    return

  obj = (get ctx, 'request.body.data.object') ? {}
  status = obj.payment_status

  if (isEmpty obj)
    (ctx.badRequest {})
    return


  user_query = [[ 'where', 'val.email', '==', obj.customer_email ]]
  user = await User.find(user_query).read()
  if !user
    (ctx.badRequest {})
    return

  payment = await Payment.get(obj.client_reference_id).read()
  if !payment
    (ctx.badRequest {})
    return

  type = payment.meta.type

  payment_paths = [ 'ext.stripe_checkout_session', 'rel.payer', 'val.status', ]
  payment_updates =
    ext: { stripe_checkout_session: obj.id }
    rel: { payer: user.meta.id }
    val: { status: if (status == 'paid') then 'paid' else 'unpaid' }
  
  payment = (Payment.create (merge {}, payment, payment_updates))
  if !(payment.ok payment_paths)
    (ctx.badRequest {})
    return


  if type == 'payment/season-team-registration'
    rQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.payment',  '==', payment.obj().meta.id ]
    ]
    registration = await Registration.find(rQ).read()
    registration = (Registration.create (merge {}, registration, {
      val:
        completed_at: (if (status == 'paid') then DateTime.local().setZone('utc').toISO() else null)
        status:       (if (status == 'paid') then 'complete' else 'incomplete')
    }))
    registration_paths = [ 'val.status', 'val.completed_at' ]
    r_status = registration.obj().val.status


    u2lQ = [
      [ 'where', 'rel.league', '==', payment.obj().rel.league ]
      [ 'where', 'rel.user',   '==', user.meta.id ]
    ]
    u2l = await UserToLeague.find(u2lQ).read()
    u2l_roles = (get u2l, 'val.roles') ? []
    user_to_league = (UserToLeague.create (merge {}, u2l, {
      index:
        user_display_name_insensitive: (toLower (trim user.val.display_name))
        user_full_name_insensitive:    (toLower (trim user.val.full_name))
      rel:
        league: payment.obj().rel.league
        user:   user.meta.id
      val: 
        roles: (uniq (union u2l_roles, [ 'manager' ]))
    }))

    u2sQ = [
      [ 'where', 'rel.user',   '==', user.meta.id ]
      [ 'where', 'rel.season', '==', payment.obj().rel.season ]
    ]
    u2s = await UserToSeason.find(u2sQ).read()
    u2s_roles = (get u2s, 'val.roles') ? []
    user_to_season = (UserToSeason.create (merge {}, u2s, {
      index:
        user_display_name_insensitive: (toLower (trim user.val.display_name))
        user_full_name_insensitive:    (toLower (trim user.val.full_name))
      rel:
        season: payment.obj().rel.season
        user:   user.meta.id
      val: 
        roles: (uniq (union u2s_roles, [ 'manager' ]))
    }))


    u2tQ = [
      [ 'where', 'rel.user', '==', user.meta.id ]
      [ 'where', 'rel.team', '==', payment.obj().rel.team ]
    ]
    u2t = await UserToTeam.find(u2tQ).read()
    u2t_roles = (get u2t, 'val.roles') ? []
    role_event = [{
      update:     'manager:added'
      updated_at: registration.obj().meta.updated_at
    }]
    user_to_team = (UserToTeam.create (merge {}, u2t, {
      index:
        user_display_name_insensitive: (toLower (trim user.val.display_name))
        user_full_name_insensitive:    (toLower (trim user.val.full_name))
      rel:
        league: payment.obj().rel.league
        season: payment.obj().rel.season
        team:   payment.obj().rel.team
        user:   user.meta.id
      val: 
        role_history: if u2t then (union [], u2t.val.role_history, role_event) else role_event
        roles:        (uniq (union u2t_roles, [ 'manager', 'primary-manager' ]))
    }))

    u2x_paths = [
      'index.user_display_name_insensitive'
      'index.user_full_name_insensitive'
      'val.roles'
    ]

    team = (Team.create {
      meta: { id: registration.obj().rel.team }
      val:  { statuses: [ "registration-#{r_status}" ] }
    })
    team_paths = [ 'val.statuses' ]

    if (any [
      (!(payment.ok payment_paths))
      (!(registration.ok registration_paths))
      (!(team.ok team_paths))
      (!(user_to_league.ok (ite u2l, u2x_paths)) && (r_status == 'complete'))
      (!(user_to_season.ok (ite u2s, u2x_paths)) && (r_status == 'complete'))
      (!(user_to_team.ok (ite u2t,   u2x_paths)) && (r_status == 'complete'))
    ])
      (ctx.badRequest {})
      return

    ok = await (Flame.transact (_t) ->
      await payment.update(payment_paths).write(_t)
      await registration.update(registration_paths).write(_t)
      await team.update(team_paths).write(_t)
      return true if (r_status != 'complete')

      await user_to_league[(ite u2l, 'update', 'save')]((ite u2l, u2x_paths)).write(_t)
      await user_to_season[(ite u2s, 'update', 'save')]((ite u2s, u2x_paths)).write(_t)
      await   user_to_team[(ite u2t, 'update', 'save')]((ite u2t, u2x_paths)).write(_t)
      return true
    )
  else
    ok = await (Flame.transact (_t) ->
      await payment.update(payment_paths).write(_t)
      return true
    )


  r = (ite ok, 'ok', 'badRequest')
  (ctx[r] {})
  return

module.exports = fn

