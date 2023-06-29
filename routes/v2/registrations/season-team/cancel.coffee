any          = require 'lodash/some'
each         = require 'lodash/each'
filter       = require 'lodash/filter'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
includes     = require 'lodash/includes'
keys         = require 'lodash/keys'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
omit         = require 'lodash/omit'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
without      = require 'lodash/without'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

ICModel  = require '@/local/models/flame-lib/invite-code'
LModel   = require '@/local/models/flame-lib/league'
PModel   = require '@/local/models/flame-lib/payment'
RModel   = require '@/local/models/flame-lib/registration'
SModel   = require '@/local/models/flame-lib/season'
SSModel  = require '@/local/models/flame-lib/season-settings'
TModel   = require '@/local/models/flame-lib/team'
U2LModel = require '@/local/models/flame-lib/user-to-league'
U2SModel = require '@/local/models/flame-lib/user-to-season'
U2TModel = require '@/local/models/flame-lib/user-to-team'
UModel   = require '@/local/models/flame-lib/user'
UserOld  = require '@/local/models/user'


ite = (c, a, b = null) -> if c then a else b

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { registration } = ctx.request.body
  
  if !uid
    (ctx.unauthorized())
    return

  (ctx.ok {})
  return

  # Flame = await FLI('main')
  # db    = await Flame.wildfire().firestore()
  
  # InviteCode     = await ICModel()
  # League         = await LModel()
  # Payment        = await PModel()
  # Registration   = await RModel()
  # Season         = await SModel()
  # SeasonSettings = await SSModel()
  # Team           = await TModel()
  # User           = await UModel()
  # UserToLeague   = await U2LModel()
  # UserToSeason   = await U2SModel()
  # UserToTeam     = await U2TModel()


  # ic_query = [
  #   [ 'where', 'val.code', '==', code ]
  #   [ 'where', 'meta.type', '==', 'invite-code/season-team' ]
  # ]

  # [ invite_code_st, user_old ] = await all([
  #   InviteCode.find(ic_query).read()
  #   UserOld.getByUid(uid)
  # ])

  # season_id = invite_code_st.rel.season

  # now = DateTime.local().setZone('utc')
  # { expires_at } = invite_code_st.val

  # if (any([
  #   (!user_old)
  #   (!invite_code_st)
  #   (invite_code_st.meta.deleted)
  #   (invite_code_st.val.uses > invite_code_st.val.max_uses)
  #   (expires_at && (now > DateTime.fromISO(expires_at)))
  # ]))
  #   ctx.badRequest({})
  #   return

  # [ season, season_settings ] = await all([
  #   Season.get(season_id).read()
  #   SeasonSettings.find([['where', 'rel.season', '==', season_id]]).read()
  # ])

  # league_id = season.rel.league

  # if (any([
  #   (!season)
  #   (!season_settings)
  #   (season.meta.deleted == true)
  #   (season.val.status != 'active')
  #   (season_settings.val.registration_status.team_season != 'open')
  # ]))
  #   ctx.badRequest({})
  #   return

  # required    = season_settings.val.required_info.manager
  # user_fields = filter(map(required, (_v, _k) -> if _v then "#{_k}" else null))
  # user_info   = pick(form, user_fields)
  # user_paths  = map(user_fields, (_f) -> "val.#{_f}")

  # user = User.create(merge(user_old, {
  #   val: merge(user_info, { email: user_old.val.email })
  # }))

  # if !user.ok(user_fields)
  #   ctx.badRequest({})
  #   return
  
  # # TODO: Migrate to NEW
  # [ league, s2uQS, seasonsQS ] = await all([
  #   League.get(league_id).read()
  #   db
  #     .collection('/seasons-to-users')
  #     .where('rel-user', '==', user.obj().meta.id)
  #     .get()
  #   db
  #     .collection('/seasons')
  #     .where('rel-league', '==', league_id)
  #     .get()
  # ])
  
  # s2us = map((s2uQS.docs ? []), (_d) -> {
  #   id: _d.id
  #   roles: _d.data()['val-access-control']
  #   season: _d.data()['rel-season']
  # })

  # season_ids = map((seasonsQS.docs ? []), (_d) -> _d.id)
  # season_ids = without(season_ids, season.meta.id)

  # is_returning = reduce(s2us, (_acc, _v) ->
  #   was_manager = includes(_v.roles, 'manager') || includes(_v.roles, 'captain')
  #   return _acc || (was_manager && includes(season_ids, _v.season))
  # , false)

  # prices =  season_settings.val.prices.team_per_season
  # fee = if is_returning then prices.returning else prices.default


  # team_id         = Team.create({}).obj().meta.id
  # registration_id = Registration.create({}).obj().meta.id
  # payment_id      = Payment.create({}).obj().meta.id if (fee > 0)

  # invite_code_tm = InviteCode.create({
  #   meta:
  #     type:   'invite-code/team-manager'
  #   rel:
  #     league: league_id
  #     season: season_id
  #     team:   team_id
  # })
  
  # invite_code_tp = InviteCode.create({
  #   meta:
  #     type:   'invite-code/team-player'
  #   rel:
  #     league: league_id
  #     season: season_id
  #     team:   team_id
  # })

  # (payment = Payment.create({
  #   ext:
  #     stripe_checkout_session: null
  #     stripe_payment_intent:   null
  #     stripe_price:            null
  #     stripe_product:          null
  #   meta:
  #     type: 'payment/season-team-registration'
  #     id:   payment_id
  #   rel:
  #     league:     league_id
  #     payee:      league_id
  #     payer:      user.obj().meta.id
  #     season:     season_id
  #     team:       team_id
  #     user:       user.obj().meta.id
  #   val:
  #     currency:    'usd'
  #     description: "Payment to #{league.val.name} for #{season.val.name} team registration."
  #     items:       [{ amount: fee, name: 'Team × Season' }]
  #     payee_type:  'league'
  #     payer_type:  'user'
  #     status:      'unpaid'
  #     title:       'Payment'
  #     total:       fee
  # })) if (fee > 0)

  # registration = Registration.create({
  #   meta:
  #     id: registration_id
  #     type: 'registration/season-team'
  #   rel:
  #     league:          league_id
  #     payment:         if (fee > 0) then payment_id else null
  #     season:          season_id
  #     season_settings: season_settings.meta.id
  #     team:            team_id
  #     user:            user.obj().meta.id
  #   val:
  #     form:            form
  #     status:          if (fee > 0) then 'incomplete' else 'complete'
  # })
  # r_status = registration.obj().val.status
  
  # team = Team.create({
  #   meta:
  #     id: team_id
  #   rel:
  #     league:          league_id
  #     manager:         user.obj().meta.id
  #     registration:    registration_id
  #     season:          season_id
  #     season_settings: season_settings.meta.id
  #   val:
  #     name:            team_info.name
  #     manager_count:   1
  #     player_count:    0
  #     statuses:        (if (r_status == 'complete') then [ 'registration-complete' ] else [ 'registration-incomplete' ])
  # })

  # u2lQ = [
  #   [ 'where', 'rel.league', '==', league_id ]
  #   [ 'where', 'rel.user', '==', user.obj().meta.id ]
  # ]
  # u2l = await UserToLeague.find(u2lQ).read()
  # u2l_roles = get(u2l, 'val.roles') ? []
  # user_to_league = UserToLeague.create({
  #   index:
  #     user_display_name_insensitive: toLower(trim(user.obj().val.display_name))
  #     user_full_name_insensitive: toLower(trim(user.obj().val.full_name))
  #   rel:
  #     league: league_id
  #     user:   user.obj().meta.id
  #   val: 
  #     roles: uniq(union(u2l_roles, [ 'manager' ]))
  # })

  # u2sQ = [
  #   [ 'where', 'rel.season', '==', season_id ]
  #   [ 'where', 'rel.user', '==', user.obj().meta.id ]
  # ]
  # u2s = await UserToSeason.find(u2sQ).read()
  # u2s_roles = get(u2s, 'val.roles') ? []
  # user_to_season = UserToSeason.create({
  #   index:
  #     user_display_name_insensitive: toLower(trim(user.obj().val.display_name))
  #     user_full_name_insensitive: toLower(trim(user.obj().val.full_name))
  #   rel:
  #     season: season_id
  #     user:   user.obj().meta.id
  #   val: 
  #     roles: uniq(union(u2s_roles, [ 'manager' ]))
  # })

  # u2tQ = [
  #   [ 'where', 'rel.user', '==', user.obj().meta.id ]
  #   [ 'where', 'rel.team', '==', team_id ]
  # ]
  # u2t = await UserToTeam.find(u2tQ).read()
  # u2t_roles = get(u2t, 'val.roles') ? []
  # user_to_team = UserToTeam.create(merge(u2t, {
  #   index:
  #     user_display_name_insensitive: toLower(trim(user.obj().val.display_name))
  #     user_full_name_insensitive: toLower(trim(user.obj().val.full_name))
  #   rel:
  #     team: team_id
  #     user: user.obj().meta.id
  #   val: 
  #     roles: uniq(union(u2t_roles, [ 'manager' ]))
  # }))

  # u2x_paths = [
  #   'index.user_display_name_insensitive'
  #   'index.user_full_name_insensitive'
  #   'val.roles'
  # ]

  # if any([
  #   (!invite_code_tm.ok())
  #   (!invite_code_tp.ok())
  #   (!payment.ok() && (fee > 0))
  #   (!registration.ok())
  #   (!team.ok())
  #   (!user.ok(user_paths))
  #   (!user_to_league.ok(ite(u2l, u2x_paths)) && (r_status == 'complete'))
  #   (!user_to_season.ok(ite(u2s, u2x_paths)) && (r_status == 'complete'))
  #   (!user_to_team.ok(ite(u2t,   u2x_paths)) && (r_status == 'complete'))
  # ])
  #   ctx.badRequest({})
  #   return

  # ok = await Flame.transact((_t) ->
  #   await invite_code_tm.save().write(_t)
  #   await invite_code_tp.save().write(_t)
  #   await payment.save().write(_t) if (fee > 0)
  #   await registration.save().write(_t)
  #   await team.save().write(_t)
  #   await user.update(user_paths).write(_t)
  #   return true if (r_status != 'complete')
      
  #   await user_to_league[ite(u2l, 'update', 'save')](ite(u2l, u2x_paths)).write(_t)
  #   await user_to_season[ite(u2s, 'update', 'save')](ite(u2s, u2x_paths)).write(_t)
  #   await user_to_team[ite(u2t,   'update', 'save')](ite(u2t, u2x_paths)).write(_t)
  #   return true
  # )

  # if !!ok
  #   ctx.ok({
  #     ...({ payment: payment.obj([ 'val.code' ]) } if !!payment)
  #   })
  # else
  #   ctx.badRequest({})
  return
