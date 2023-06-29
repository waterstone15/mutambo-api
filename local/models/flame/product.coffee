Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      ext:
        stripe_product: null
      meta:
        type: 'product'
        v: 100
    ok:
      ext:
        stripe_product: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model