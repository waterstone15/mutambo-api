FLI          = require '@/local/lib/flame-lib-init'
log          = require '@/local/lib/log'
isEmpty      = require 'lodash/isEmpty'
isObject     = require 'lodash/isObject'
isString     = require 'lodash/isString'
toString     = require 'lodash/toString'
rand         = require '@stablelib/random'
{ DateTime } = require 'luxon'

Model = ->
  Flame = (await FLI 'main')

  M = (Flame.model 'GameSheet', {
    data:
      meta:
        v:                '00000.00000.00000'
      rel:
        away_team:        null
        game:             null
        home_team:        null
        league:           null
        season:           null
      val:
        away_roster:      null
        code:             (_d) -> (rand.randomString 36)
        home_roster:      null
    validators:
      rel:
        away_team:        (_v) -> !(isEmpty _v) && (isString _v)
        game:             (_v) -> !(isEmpty _v) && (isString _v)
        home_team:        (_v) -> !(isEmpty _v) && (isString _v)
        league:           (_v) -> !(isEmpty _v) && (isString _v)
        season:           (_v) -> !(isEmpty _v) && (isString _v)
      val:
        away_roster:      (_v) -> (isObject _v)
        code:             (_v) -> (isString _v)
        home_roster:      (_v) -> (isObject _v)

  })

  return M


module.exports = Model

