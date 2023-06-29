Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isNumber   = require 'lodash/isNumber'
isString   = require 'lodash/isString'

Model = (->

  currency_opts = { require_decimal: true }

  _Model = Flame.extend({
    obj:
      meta:
        type: 'standing-settings'
        v: 100
      val:
        forefit_loss_points: 0
        forefit_win_points: 0
        loss_points: 0
        score_points_per_point: 0
        tie_points: 0
        tiebreaker_order: [
          'most-wins'
          'least-losses'
          'most-goals-for'
          'least-goals-against'
          'head-to-head-record'
          'head-to-head-goal-difference'
          'random'
        ]
        win_points: 0
      rel:
        league: null
        season: null
    ok:
      val:
        win_points: (v) -> isNumber(v)
        loss_points: (v) -> isNumber(v)
        forefit_win_points: (v) -> isNumber(v)
        forefit_loss_points: (v) -> isNumber(v)
        tiebreaker_order: -> true
      rel:
        league: (v) -> !isEmpty(v) && isString(v)
        season: (v) -> !isEmpty(v) && isString(v)
  })

  return _Model

)()
module.exports = Model