Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      index:
        name_insensitive: null
      meta:
        type: 'season-to-facility'
        collection: 'seasons-to-facilities'
        v: 100
      rel:
        season: null
        facility: null
    ok:
      index:
        name_insensitive: (v) -> !isEmpty(v) && isString(v)
      rel:
        season: (v) -> !isEmpty(v) && isString(v)
        facility: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model
