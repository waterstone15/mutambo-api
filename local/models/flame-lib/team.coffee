FLI       = require '@/local/lib/flame-lib-init'
isArray   = require 'lodash/isArray'
isEmpty   = require 'lodash/isEmpty'
isInteger = require 'lodash/isInteger'
isNull    = require 'lodash/isNull'
isObject  = require 'lodash/isObject'
isString  = require 'lodash/isString'
size      = require 'lodash/size'
trim      = require 'lodash/trim'


Model = ->
  Flame = (await FLI 'main')

  M = (Flame.model 'Team', {
    data:
      index:
        name_insensitive: ''
      meta:
        v:                '00000.00000.00000'
      rel:
        division:         null
        league:           null
        manager:          null
        registration:     null
        season:           null
        season_settings:  null
      val:
        name:             null
        statuses:         []
    validators:
      index:
        name_insensitive: (_v) -> isString(_v)
      rel:
        division:         (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        manager:          (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        league:           (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        registration:     (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season:           (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season_settings:  (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      val:
        name:             (_v) -> (isString _v) && (1 <= (size (trim _v)) <= 50)
        statuses:         (_v) -> (isArray _v)

  })

  return M


module.exports = Model

