FLI           = require '@/local/lib/flame-lib-init'
includes      = require 'lodash/includes'
isArray       = require 'lodash/isArray'
isEmpty       = require 'lodash/isEmpty'
isNull        = require 'lodash/isNull'
isNumber      = require 'lodash/isNumber'
isSafeInteger = require 'lodash/isSafeInteger'
isString      = require 'lodash/isString'
log           = require '@/local/lib/log'
rand          = require '@stablelib/random'
trim          = require 'lodash/trim'
{ DateTime }  = require 'luxon'


Model = ->
  Flame = await (FLI 'main')

  ok_status = [ 'paid', 'refunded', 'unpaid', ]

  M = (Flame.model 'Payment', {
    data:
      ext:
        stripe_checkout_session: null
        stripe_payment_intent:   null
        stripe_price:            null
        stripe_product:          null
        stripe_refund:           null
      meta:
        v: '00000.00000.00000'
      rel:
        game:       null
        league:     null
        misconduct: null
        payee:      null
        payer:      null # the entity that paid this payment (person, league, team, etc.)
        season:     null
        team:       null
        user:       null # who is responsible to pay this payment
      val:
        code: ((_d) ->
          dt = DateTime.local().setZone('utc').toFormat('yyyyooo')
          r  = (rand.randomString 32)
          "#{r}-#{parseInt(dt).toString(36)}"
        )
        currency:    'usd'
        description: null
        expires_at:  null
        items:       null
        password:    null
        payee_type:  null
        payer_type:  null
        status:      'unpaid'
        title:       'Payment'
        total:       null
    validators:
      meta:
        type: (_v) ->
          ok_types = [
            'payment'
            'payment/misconduct'
            'payment/season-team-registration'
          ]
          return (includes ok_types, _v)
      ext:
        stripe_checkout_session: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        stripe_payment_intent:   (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        stripe_price:            (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        stripe_product:          (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        stripe_refund:           (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      rel:
        game:       (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        league:     (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        misconduct: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        payee:      (_v) -> (isString _v) && !(isEmpty (trim _v))
        payer:      (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season:     (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        team:       (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        user:       (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      val:
        code:        (_v) -> (isEmpty _v) || ((isString _v) && !(isEmpty (trim _v)))
        currency:    (_v) -> (_v == 'usd')
        description: (_v) -> (isString _v) && !(isEmpty (trim _v))
        expires_at:  (_v) -> (isEmpty _v) || ((isString _v) && !(isEmpty (trim _v)))
        items:       (_v) -> isArray(_v) && !(isEmpty _v)
        password:    (_v) -> (isEmpty _v) || ((isString _v) && !(isEmpty (trim _v)))
        payee_type:  (_v) -> (includes [ 'league' ], _v)
        payer_type:  (_v) -> (includes [ 'user' ], _v)
        status:      (_v) -> (includes ok_status, _v)
        title:       (_v) -> (isString _v) && !(isEmpty (trim _v))
        total:       (_v) -> (isNumber _v) && (_v >= 0)

  })

  return M


module.exports = Model

