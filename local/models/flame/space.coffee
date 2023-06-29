Flame      = require '@/local/lib/flame'
isArray    = require 'lodash/isArray'
isEmpty    = require 'lodash/isEmpty'
isNumber   = require 'lodash/isNumber'
isString   = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      index:
        name_insensitive: null
      meta:
        type: 'space'
        v: 100
      val:
        address: null
        latitude: null
        longitude: null
        name: null
        parking: null
      rel:
        conflicts: null
        facility: null
    ok:
      index:
        name_insensitive: (v) -> !isEmpty(v) && isString(v)
      val:
        address:   (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        latitude:  (v) -> isEmpty(v) || (!isEmpty(v) && isNumber(v))
        longitude: (v) -> isEmpty(v) || (!isEmpty(v) && isNumber(v))
        name:      (v) -> !isEmpty(v) && isString(v)
        parking:   (v) -> isEmpty(v) || (!isEmpty(v) && isArray(v))
      rel:
        conflicts: (v) -> isEmpty(v) || (!isEmpty(v) && isArray(v))
        facility:  (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
  })

  return _Model

)()
module.exports = Model
