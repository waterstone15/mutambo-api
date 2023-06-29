Flame     = require '@/local/lib/flame'
includes  = require 'lodash/includes'
isBoolean = require 'lodash/isBoolean'
isEmpty   = require 'lodash/isEmpty'
isObject  = require 'lodash/isObject'
isString  = require 'lodash/isString'

Model = (->

  _Model = Flame.extend({
    obj:
      meta:
        type: 'notification'
        v: 100
      val:
        body: null
        data: null
        status: 'to-do'
        title: null
        type: null
      rel:
        assignee: null
        season: null
        user: null
    ok:
      val:
        body: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        data: (v) -> isEmpty(v) || (!isEmpty(v) && isObject(v))
        status: (v) -> includes([ 'to-do', 'assigned', 'complete' ], v)
        title: (v) -> !isEmpty(v) && isString(v)
        type: (v) -> !isEmpty(v) && isString(v)
      rel:
        assignee: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        season: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        user: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
  })

  return _Model

)()
module.exports = Model