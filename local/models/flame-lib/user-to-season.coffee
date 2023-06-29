every    = require 'lodash/every'
FLI      = require '@/local/lib/flame-lib-init'
hash     = require '@/local/lib/hash'
includes = require 'lodash/includes'
isArray  = require 'lodash/isArray'
isEmpty  = require 'lodash/isEmpty'
isString = require 'lodash/isString'
trim     = require 'lodash/trim'


Model = ->
  Flame = await FLI('main')

  ok_roles = [ 'admin', 'manager', 'player', ]

  M = Flame.model('UserToSeason', {
    data:
      index:
        user_display_name_insensitive: ''
        user_full_name_insensitive:    ''
      meta:
        collection: 'users-to-seasons'
        id:         (_d) -> 'user-to-season-' + hash.sha256("#{_d.rel.user}-#{_d.rel.season}")
        v:          '00000.00000.00000'
      rel:
        season: null
        user:   null
      val:
        roles: null
    validators:
      index:
        user_display_name_insensitive: (_v) -> (isString _v)
        user_full_name_insensitive:    (_v) -> (isString _v)
      rel:
        season: (_v) -> (isString _v) && !(isEmpty (trim _v))
        user:   (_v) -> (isString _v) && !(isEmpty (trim _v))
      val:
        roles: (_v) ->
          return (isArray _v) && (every _v, (_r) -> (includes ok_roles, _r))
  })

  return M


module.exports = Model
