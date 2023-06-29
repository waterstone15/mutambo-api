FLI          = require '@/local/lib/flame-lib-init'
hash         = require '@/local/lib/hash'
isEmpty      = require 'lodash/isEmpty'
isString     = require 'lodash/isString'
trim         = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  M = (Flame.model 'CardToLeague', {
    data:
      meta:
        collection: 'cards-to-leagues'
        id:         (_d) -> 'card-to-league-' + (hash.sha256 "#{_d.rel.card}-#{_d.rel.league}")
        v:          '00000.00000.00000'
      rel:
        league: null
        card:   null
    validators:
      rel:
        league: (_v) -> (isString _v) && !(isEmpty (trim _v))
        card:   (_v) -> (isString _v) && !(isEmpty (trim _v))
  })

  return M


module.exports = Model
