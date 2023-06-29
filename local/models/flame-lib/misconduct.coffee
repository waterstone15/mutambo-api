_            = require 'lodash'
FLI          = require '@/local/lib/flame-lib-init'
includes     = require 'lodash/includes'
isArray      = require 'lodash/isArray'
isBoolean    = require 'lodash/isBoolean'
isEmpty      = require 'lodash/isEmpty'
isInteger    = require 'lodash/isInteger'
isNull       = require 'lodash/isNull'
isObject     = require 'lodash/isObject'
isString     = require 'lodash/isString'
log          = require '@/local/lib/log'
size         = require 'lodash/size'
trim         = require 'lodash/trim'
{ DateTime } = require 'luxon'


Model = ->
  Flame = (await FLI 'main')

  M = (Flame.model 'Misconduct', {
    data:
      meta:
        v:                       '00000.00000.00000'
      rel:
        game:                    null
        league:                  null
        payment:                 null
        season:                  null
        team:                    null
        user:                    null
      val:
        auto:                    null
        demerits:                0
        description:             null
        notes:                   null
        return_after_clock_time: null
        return_after_games:      null
        return_after_payment:    null
        return_after_timezone:   null
        return_after_utc:        null
        scopes:                  []
        status:                  'resolved'
        suspend:                 false
        suspension_end_utc:      null
        suspension_start_utc:    null
        type:                    null
    validators:
      rel:
        game:                    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        league:                  (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        payment:                 (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        season:                  (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        team:                    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        user:                    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
      val:
        auto:                    (_v) -> (isBoolean _v)
        demerits:                (_v) -> (isInteger _v) && (_v >= 0)
        description:             (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        notes:                   (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        return_after_clock_time: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        return_after_games:      (_v) -> (isNull _v) || ((isInteger _v) && (_v >= 0))
        return_after_payment:    (_v) -> (isNull _v) || (isBoolean _v)
        return_after_timezone:   (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        return_after_utc:        (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        scopes:                  (_v) -> (isArray _v)
        status:                  (_v) -> (includes [ 'resolved', 'suspended' ], _v)
        suspend:                 (_v) -> (isBoolean _v)
        suspension_end_utc:      (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        suspension_start_utc:    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty _v))
        type:                    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
  })

  return M


module.exports = Model


