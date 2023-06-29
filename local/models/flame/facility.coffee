Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'
toLower    = require 'lodash/toLower'
trim       = require 'lodash/trim'

Model = (->

  _Model = Flame.extend({
    obj:
      index:
        name_insensitive: null
      meta:
        type: 'facility'
        v: 100
      val:
        abbreviation: null
        address: null
        latitude: null
        longitude: null
        name: null
        website: null
    ok:
      index:
        name_insensitive: (v) -> !isEmpty(v) && isString(v)
      val:
        abbreviation: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        address:      (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        latitude:     (v) -> isEmpty(v) || (!isEmpty(v) && isNumber(v))
        longitude:    (v) -> isEmpty(v) || (!isEmpty(v) && isNumber(v))
        name:         (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        website:      (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
  })

  return _Model

)()
module.exports = Model


