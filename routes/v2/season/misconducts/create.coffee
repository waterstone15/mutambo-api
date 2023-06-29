any          = require 'lodash/some'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
money        = require 'currency.js'
pick         = require 'lodash/pick'
readInt      = require 'lodash/parseInt'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
LModel       = require '@/local/models/flame-lib/league'
MModel       = require '@/local/models/flame-lib/misconduct'
PModel       = require '@/local/models/flame-lib/payment'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'

ite = (a, b, c = null) -> if a then b else c

module.exports = (ctx) ->
  
  { uid } = ctx.state.fbUser
  form    = ctx.request.body

  Flame        = await (FLI 'main')

  Game         = await GModel()
  League       = await LModel()
  Misconduct   = await MModel()
  Payment      = await PModel()
  Season       = await SModel()
  Team         = await TModel()
  U2S          = await U2SModel()
  U2T          = await U2TModel()
  User         = await UModel()

  gQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', form.rel.game ]
    [ 'where', 'rel.league',   '==', form.rel.league ]
    [ 'where', 'rel.season',   '==', form.rel.season ]
  ]
  p2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', form.rel.team ]
    [ 'where', 'rel.user',     '==', form.rel.person ]
    [ 'where', 'val.roles',    'array-contains-any', [ 'manager', 'player' ]]
  ]
  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', form.rel.season ]
    [ 'where', 'rel.league',   '==', form.rel.league ]
  ]
  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', form.rel.team ]
    [ 'where', 'rel.league',   '==', form.rel.league ]
    [ 'where', 'rel.season',   '==', form.rel.season ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  gF   = [ 'meta.id', 'rel.away_team', 'rel.home_team', 'val.start_utc' ]
  lF   = [ 'meta.id', 'val.name' ]
  p2tF = [ 'meta.id' ]
  pF   = [ 'meta.id', 'val.full_name' ]
  sF   = [ 'meta.id', 'val.name' ]
  tF   = [ 'meta.id', 'val.name', ]
  uF   = [ 'meta.id' ]
 
  [ game, league, p2t, person, season, team, user, ] = await (all [
    Game   .find(gQ, gF)             .read()
    League .get(form.rel.league, lF) .read()
    U2T    .find(p2tQ, p2tF)         .read()
    User   .get(form.rel.person, pF) .read()
    Season .find(sQ, sF)             .read()
    Team   .find(tQ, tF)             .read()
    User   .find(uQ, uF)             .read()
  ])

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', form.rel.season ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2s = await (U2S.find u2sQ).read()

  if (any [
    !game, !league, !p2t, !person, !season, !team, !u2s, !user,
    !(includes [ game.rel.home_team, game.rel.away_team ], team.meta.id)
    !(includes [ 'league', 'season', 'team' ], form.val.scope)
  ])
    (ctx.badRequest {})
    return

  now = DateTime.local().setZone('utc')
  
  scope  = form.val.scope
  _scope = switch scope
    when 'league' then "#{scope}:#{league.meta.id}"
    when 'season' then "#{scope}:#{season.meta.id}"
    when 'team'   then "#{scope}:#{team.meta.id}"

  misconduct_id = (Misconduct.create {}).obj().meta.id

  amount = (money form.val.fee).value
  payment = null

  if (amount && (amount > 0))
    date_fmt = (ite (game?.val?.start_utc), " on #{DateTime.fromISO(game.val.start_utc).toFormat('yyyy.M.d')}", '')

    payment = (Payment.create {
      rel:
        game:       game.meta.id
        league:     league.meta.id
        misconduct: misconduct_id
        payee:      league.meta.id
        season:     season.meta.id
        team:       team.meta.id
      val:
        description: "Payment to #{league.val.name}, #{season.val.name} for #{person.val.full_name}'s misconduct#{date_fmt}."
        items: [{
          amount: amount
          name:   'Misconduct Payment'
        }]
        payee_type: 'league'
        payer_type: 'user'
        title:      'Misconduct Payment'
        total:      amount
    })
    if !payment.ok()
      (ctx.badRequest {})
      return

  misconduct = (Misconduct.create {
    meta:
      id:       misconduct_id
      type:     'payment/misconduct'
    rel:
      game:     game.meta.id
      league:   league.meta.id
      payment:  if !!payment then payment.obj().meta.id else null
      season:   season.meta.id
      team:     team.meta.id
      user:     person.meta.id
    val:
      auto:     false
      demerits: (readInt form.val.demerits)
      scopes:   [ _scope ]
      status:   'suspended'
      suspend:  true
      suspension_start_utc: now.toISO()
  })
  if !misconduct.ok()
    (ctx.badRequest {})
    return

  ok = await (Flame.transact (_t) ->
    (await payment    .save() .write(_t)) if payment
    (await misconduct .save() .write(_t))
    return true
  )

  r = (ite ok, 'ok', 'badRequest')
  (ctx[r] {})
  return



