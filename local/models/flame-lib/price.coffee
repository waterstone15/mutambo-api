FLI        = require '@/local/lib/flame-lib-init'
hash       = require '@/local/lib/hash'
includes   = require 'lodash/includes'
isCurrency = require 'validator/lib/isCurrency'
isEmpty    = require 'lodash/isEmpty'
isNull     = require 'lodash/isNull'
isNumber   = require 'lodash/isNumber'
isString   = require 'lodash/isString'
trim       = require 'lodash/trim'


Model = ->
  Flame = await FLI('main')

  currency_opts = { require_decimal: true }

  M = Flame.model('Price', {
    data:
      ext:
        stripe_price:   null
        stripe_product: null
      meta:
        id: (_d) ->
          'price-' + hash.sha256("#{_d.ext.stripe_product}-#{_d.ext.stripe_price}")
        
        v: '00000.00000.00000'
      val:
        amount:         null
        currency:       null
        price:          null
    validators:
      ext:
        stripe_price:   (_v) -> isString(_v) && !isEmpty(trim(_v))
        stripe_product: (_v) -> isString(_v) && !isEmpty(trim(_v))
      val:
        amount:         (_v) -> isNumber(_v) && _v >= 0
        currency:       (_v) -> includes([ 'usd' ], _v)
        price:          (_v) -> isNull(_v) || isCurrency(_v, currency_opts)
  })

  return M


module.exports = Model