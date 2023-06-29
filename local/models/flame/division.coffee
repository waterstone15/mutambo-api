Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      meta:
        type: 'division'
        v: 100
      val:
        name: null
      rel:
        league: null
        season: null
    ok:
      val:
        name: (v) -> !isEmpty(v) && isString(v)
      rel:
        league: (v) -> !isEmpty(v) && isString(v)
        season: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model
