FLI      = require '@/local/lib/flame-lib-init'
includes = require 'lodash/includes'
isEmpty  = require 'lodash/isEmpty'
isNull   = require 'lodash/isNull'
isObject = require 'lodash/isObject'
isString = require 'lodash/isString'
trim     = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  ok_status = [ 'incomplete', 'complete', 'canceled' ]

  M = (Flame.model 'Registration', {
    data:
      meta:
        type: null
        v:    '00000.00000.00000'
      rel:
        game:            null
        league:          null
        payment:         null
        season:          null
        season_settings: null
        team:            null
        user:            null
      val:
        completed_at:    null
        form:            {}
        status:          'incomplete'
    validators:
      rel:
        game:            (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        league:          (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        payment:         (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season:          (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season_settings: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        team:            (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        user:            (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      val:
        completed_at:    (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        form:            (_v) -> (isObject _v)
        status:          (_v) -> (includes ok_status, _v)

  })

  return M


module.exports = Model

