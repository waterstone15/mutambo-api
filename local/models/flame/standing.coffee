Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isNumber   = require 'lodash/isNumber'
isString   = require 'lodash/isString'
isInteger  = require 'lodash/isInteger'

Model = (->

  _Model = Flame.extend({
    obj:
      meta:
        type: 'standing'
        v: 100
      val:
        forefit_losses: 0
        forefit_ties: 0
        forefit_wins: 0
        goals_against: 0
        goals_for: 0
        losses: 0
        points: 0
        rank: 9007199254740991
        ties: 0
        wins: 0
      rel:
        division: null
        league: null
        season: null
        team: null
    ok:
      val:
        forefit_losses: (v) -> isInteger(v) && v >= 0
        forefit_ties: (v) -> isInteger(v) && v >= 0
        forefit_wins: (v) -> isInteger(v) && v >= 0
        goals_against: (v) -> isInteger(v) && v >= 0
        goals_for: (v) -> isInteger(v) && v >= 0
        losses: (v) -> isInteger(v) && v >= 0
        points: (v) -> isNumber(v)
        rank: (v) -> isInteger(v) && v >= 1
        ties: (v) -> isInteger(v) && v >= 0
        wins: (v) -> isInteger(v) && v >= 0
      rel:
        division: (v) -> !isEmpty(v) && isString(v)
        league: (v) -> !isEmpty(v) && isString(v)
        season: (v) -> !isEmpty(v) && isString(v)
        team: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model