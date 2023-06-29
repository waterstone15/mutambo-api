every    = require 'lodash/every'
FLI      = require '@/local/lib/flame-lib-init'
has      = require 'lodash/has'
hash     = require '@/local/lib/hash'
includes = require 'lodash/includes'
isArray  = require 'lodash/isArray'
isEmpty  = require 'lodash/isEmpty'
isNull   = require 'lodash/isNull'
isString = require 'lodash/isString'
reduce   = require 'lodash/reduce'
trim     = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  ok_roles = [
    'alternate'
    'manager'
    'manager-removed'
    'player'
    'player-removed'
    'primary-manager'
  ]

  history_fields = [
    'updated_at'
    'update'
  ]

  M = (Flame.model 'UserToTeam', {
    data:
      index:
        user_display_name_insensitive: ''
        user_full_name_insensitive:    ''
      meta:
        collection: 'users-to-teams'
        id:         (_d) -> 'user-to-team-' + (hash.sha256 "#{_d.rel.user}-#{_d.rel.team}")
        v:          '00000.00000.00000'
      rel:
        league: null
        season: null
        team:   null
        user:   null
      val:
        role_history: null
        roles:        null
    validators:
      index:
        user_display_name_insensitive: (_v) -> (isString _v)
        user_full_name_insensitive:    (_v) -> (isString _v)
      rel:
        league: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        season: (_v) -> (isNull _v) || ((isString _v) && !(isEmpty (trim _v)))
        team:   (_v) -> (isString _v) && !(isEmpty (trim _v))
        user:   (_v) -> (isString _v) && !(isEmpty (trim _v))
      val:
        role_history: (_v) ->
          return (every [
            (isArray _v) 
            (every _v, (_h) -> (reduce history_fields, ((_acc, _f) -> (_acc && (has _h, _f))), true))
          ])
        roles: (_v) ->
          return (isArray _v) && (every _v, (_r) -> (includes ok_roles, _r))
  })

  return M


module.exports = Model
