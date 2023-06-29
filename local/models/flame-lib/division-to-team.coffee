FLI          = require '@/local/lib/flame-lib-init'
hash         = require '@/local/lib/hash'
isEmpty      = require 'lodash/isEmpty'
isString     = require 'lodash/isString'
trim         = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  M = (Flame.model 'DivisionToTeam', {
    data:
      meta:
        collection: 'divisions-to-teams'
        id:         (_d) -> 'division-to-team-' + (hash.sha256 "#{_d.rel.division}-#{_d.rel.team}")
        v:          '00000.00000.00000'
      rel:
        division: null
        season:   null
        team:     null
    validators:
      rel:
        division: (_v) -> (isString _v) && !(isEmpty (trim _v))
        season:   (_v) -> (isString _v) && !(isEmpty (trim _v))
        team:     (_v) -> (isString _v) && !(isEmpty (trim _v))
  })

  return M


module.exports = Model
