every     = require 'lodash/every'
FLI       = require '@/local/lib/flame-lib-init'
has       = require 'lodash/has'
isArray   = require 'lodash/isArray'
isEmpty   = require 'lodash/isEmpty'
isNull    = require 'lodash/isNull'
isString  = require 'lodash/isString'
reduce    = require 'lodash/reduce'
trim      = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  results_fields = [
    'rel.away_team'
    'rel.game'
    'rel.home_team'
    'val.score.away'
    'val.score.home'
  ]

  M = (Flame.model 'Standings', {
    data:
      meta:
        v:        '00000.00000.00000'
      rel:
        league:   null
        season:   null
        division: null
      val:
        results:  []
    validators:
      rel:
        league:   (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season:   (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        division: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      val:
        results:  (_v) -> (every [
          (isArray _v) 
          (every _v, (_r) -> (reduce results_fields, ((_acc, _f) -> (_acc && (has _r, _f))), true))
        ])
  })
  

  return M


module.exports = Model