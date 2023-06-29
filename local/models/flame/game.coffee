Flame        = require '@/local/lib/flame'
isBoolean    = require 'lodash/isBoolean'
isEmpty      = require 'lodash/isEmpty'
isInteger    = require 'lodash/isInteger'
isObject     = require 'lodash/isObject'
isString     = require 'lodash/isString'
{ DateTime } = require 'luxon'

Model = (->

  _Model = Flame.extend({
    obj:
      ext:
        gameofficials: null
      meta:
        type: 'game'
        v: 100
      rel:
        away_team: null
        division: null
        home_team: null
        league: null
        season: null
      val:
        canceled: false
        location_text: null
        score: { home: null, away: null }
        start_clock_time: null
        start_timezone: null
    ok:
      ext:
        gameofficials: (v) -> isEmpty(v) || isInteger(v)
      rel:
        away_team: (v) -> !isEmpty(v) && isString(v)
        division: (v) -> !isEmpty(v) && isString(v)
        home_team: (v) -> !isEmpty(v) && isString(v)
        league: (v) -> !isEmpty(v) && isString(v)
        season: (v) -> !isEmpty(v) && isString(v)
      val:
        canceled: (v) -> isBoolean(v)
        location_text: (v) -> isEmpty(v) && (!isEmpty(v) && isString(v))
        score: (v) -> !isEmpty(v) && isObject(v)
        start_clock_time: (v) -> !isEmpty(v) && isString(v)
        start_timezone: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model
