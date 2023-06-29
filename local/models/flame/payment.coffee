currency   = require 'currency.js'
every      = require 'lodash/every'
Flame      = require '@/local/lib/flame'
includes   = require 'lodash/includes'
isArray    = require 'lodash/isArray'
isBoolean  = require 'lodash/isBoolean'
isCurrency = require 'validator/lib/isCurrency'
isEmpty    = require 'lodash/isEmpty'
isNull     = require 'lodash/isNull'
isObject   = require 'lodash/isObject'
isString   = require 'lodash/isString'

Model = (->

  currency_opts = { require_decimal: true }

  isValidItem = (i) ->
    return (every([
      (!isEmpty(i.name) && isString(i.name))
      isCurrency(i.price, currency_opts)
      isCurrency(i.total, currency_opts)
      (!isEmpty(i.quantity) && isNumber(i.quantity))
    ]))

  _Model = Flame.extend({
    obj:
      ext:
        stripe_checkout_session: null
        stripe_payment_intent: null
      meta:
        type: 'payment'
        v: 100
      val:
        code: null
        currency: null
        description: null
        items: null
        payee_type: null
        status: 'unpaid'
        title: 'Payment'
        total: null
      rel:
        league: null
        misconduct: null
        payee: null
        payer: null
        price: null
        product: null
        product: null
        refund: null
        season: null
    ok:
      ext:
        stripe_checkout_session: (v) -> isNull(v) || (!isEmpty(v) && isString(v))
      val:
        code:        (v) -> !isEmpty(v) && isString(v)
        currency:    (v) -> includes([ 'usd' ], v)
        description: (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
        items:       (v) -> !isEmpty(v) && isArray(v) && every(v, isValidItem)
        payee_type:  (v) -> isNull(v) || includes([ 'league' ], v)
        payer_type:  (v) -> isNull(v) || includes([ 'user' ], v)
        status:      (v) -> includes([ 'unpaid', 'paid', 'canceled', 'refunded' ], v)
        title:       (v) -> !isEmpty(v) && isString(v)
        total:       (v) -> isCurrency(v, currency_opts)
      rel:
        league:     (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
        misconduct: (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
        payee:      (v) -> !isEmpty(v) && isString(v)
        payer:      (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
        price:      (v) -> !isEmpty(v) && isString(v)
        product:    (v) -> !isEmpty(v) && isString(v)
        refund:     (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
        season:     (v) -> isNull(v) || (!isEmpty(v) && isObject(v))
  })

  return _Model

)()
module.exports = Model
