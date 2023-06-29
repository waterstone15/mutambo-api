Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      index:
        name_insensitive: null
      meta:
        type: 'facility-to-space'
        collection: 'facility-to-spaces'
        v: 100
      rel:
        facility: null
        space: null
    ok:
      index:
        name_insensitive: (v) -> !isEmpty(v) && isString(v)
      rel:
        facility: (v) -> !isEmpty(v) && isString(v)
        space: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model
