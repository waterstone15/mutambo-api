FLI       = require '@/local/lib/flame-lib-init'
isBoolean = require 'lodash/isBoolean'
isEmpty   = require 'lodash/isEmpty'
isInteger = require 'lodash/isInteger'
isNull    = require 'lodash/isNull'
isObject  = require 'lodash/isObject'
isString  = require 'lodash/isString'


Model = ->
  Flame = (await FLI 'main')

  M = (Flame.model 'Game', {
    data:
      ext:
        gameofficials:    null
      meta:
        v:                '00000.00000.00000'
      rel:
        away_team:        null
        division:         null
        home_team:        null
        league:           null
        season:           null
      val:
        canceled:         false
        location_text:    null
        score:            { home: null, away: null }
        start_clock_time: null
        start_utc:        null
        start_timezone:   null
    validators:
      ext:
        gameofficials:    (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
      rel:
        away_team:        (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        division:         (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        home_team:        (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        league:           (_v) -> !(isEmpty _v) && (isString _v)
        season:           (_v) -> !(isEmpty _v) && (isString _v)
      val:
        canceled:         (_v) -> (isBoolean _v)
        location_text:    (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        score:            (_v) -> !(isEmpty _v) && (isObject _v)
        start_clock_time: (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        start_utc:        (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))
        start_timezone:   (_v) -> (isNull _v) || (!(isEmpty _v) && (isString _v))

  })

  return M


module.exports = Model
