currency   = require 'currency.js'
Flame      = require '@/local/lib/flame'
includes   = require 'lodash/includes'
isCurrency = require 'validator/lib/isCurrency'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'

Model = (->

  currency_opts = { require_decimal: true }

  _Model = Flame.extend({
    obj:
      ext:
        stripe_price: null
      meta:
        type: 'price'
        v: 100
      val:
        currency: null
        price: null
      rel:
        product: null
    ok:
      ext:
        stripe_price: (v) -> !isEmpty(v) && isString(v)
      val:
        currency: (v) -> includes([ 'usd' ], v)
        price: (v) -> isCurrency(v, currency_opts)
      rel:
        product: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model