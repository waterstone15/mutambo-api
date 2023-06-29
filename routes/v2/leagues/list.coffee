FLI          = require '@/local/lib/flame-lib-init'
includes     = require 'lodash/includes'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
isNull       = require 'lodash/isNull'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
sortBy       = require 'lodash/sortBy'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
U2LModel     = require '@/local/models/flame-lib/user-to-league'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  League       = await LModel()
  User         = await UModel()
  UserToLeague = await U2LModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()
  
  if !user
    ctx.badRequest({})
    return

  u2lQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  user_to_leagues = await UserToLeague.findAll(u2lQ).read()

  if !user_to_leagues
    ctx.badRequest({})
    return
  
  league_acl =
    public: [ 'meta.deleted', 'meta.id', 'val' ]
    player: []
    captain: []
    manager: []
    admin: []

  leagues = await all(map(user_to_leagues, (_u2l) ->
    league = await League.get(_u2l.rel.league).read()

    fields = reduce(_u2l.val.roles, ((_acc, _role) ->
      uniq(union(_acc, league_acl[_role])))
    , league_acl.public)

    league = pick(league, fields)

    roles = sortBy(_u2l.val.roles)
    league = merge(league, {
      val:
        is_admin:   includes(roles, 'admin')
        is_captain: includes(roles, 'captain')
        is_manager: includes(roles, 'manager')
        is_player:  includes(roles, 'player')
        roles:      roles
    })
    return league
  ))

  ctx.ok({ leagues })
  return
