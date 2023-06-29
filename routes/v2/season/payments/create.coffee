any          = require 'lodash/some'
log          = require '@/local/lib/log'
money        = require 'currency.js'
{ all }      = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
PModel       = require '@/local/models/flame-lib/payment'
SModel       = require '@/local/models/flame-lib/season'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  { uid } = ctx.state.fbUser
  form    = ctx.request.body

  League       = await LModel()
  Payment      = await PModel()
  Season       = await SModel()
  U2S          = await U2SModel()
  User         = await UModel()

  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', form.rel.season ]
    [ 'where', 'rel.league',   '==', form.rel.league ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  lF   = [ 'meta.id' ]
  sF   = [ 'meta.id' ]
  uF   = [ 'meta.id' ]
 
  [ league, season, user, ] = await (all [
    League .get(form.rel.league, lF) .read()
    Season .find(sQ, sF)             .read()
    User   .find(uQ, uF)             .read()
  ])

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', form.rel.season ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2s = await (U2S.find u2sQ).read()

  if (any [ !league, !season, !u2s, !user, ])
    (ctx.badRequest {})
    return

  payment = (Payment.create {
    rel:
      league: form.rel.league
      payee:  form.rel.league
      season: form.rel.season
    val:
      description: form.val.description
      items: [{
        amount: (money form.val.amount).value
        name:   form.val.title
      }]
      payee_type: 'league'
      payer_type: 'user'
      title:      form.val.title
      total:      (money form.val.amount).value
  })

  if !payment.ok()
    (ctx.badRequest {})
    return

  await payment.save().write()

  (ctx.ok {})
  return



