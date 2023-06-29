FLI       = require '@/local/lib/flame-lib-init'
gte       = require 'lodash/gte'
includes  = require 'lodash/includes'
isEmpty   = require 'lodash/isEmpty'
isInteger = require 'lodash/isInteger'
isNull    = require 'lodash/isNull'
isString  = require 'lodash/isString'
trim      = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  M = (Flame.model 'Division', {
    data:
      meta:
        v:     '00000.00000.00000'
      rel:
        league: null
        season: null
      val:
        name:   null
        rank:   null
    validators:
      rel:
        league: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
      val:
        name:   (_v) -> (isString _v) && !(isEmpty (trim _v))
        rank:   (_v) -> (isNull _v) || ((isInteger _v) && (gte _v, 0))
  })

  return M


module.exports = Model