get      = require 'lodash/get'
hash     = require '@/local/lib/hash'
includes = require 'lodash/includes'
LModel   = require '@/local/models/flame-lib/league'
log      = require '@/local/lib/log'
merge    = require 'lodash/merge'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
sortBy   = require 'lodash/sortBy'
U2LModel = require '@/local/models/flame-lib/user-to-league'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { league_id } = ctx.request.body

  League = await LModel()
  UserToLeague = await U2LModel()

  user = await User.getByUid(uid)

  u2lQ = [
    [ 'where', 'rel.league', '==', league_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ league, u2l ] = await all([
    League.get(league_id).read()
    UserToLeague.find(u2lQ).read()
  ])

  if !league || league.meta.deleted
    ctx.badRequest()
    return

  acl =
    public: [
      'meta.created_at'
      'meta.id'
      'val.description'
      'val.logo_url'
      'val.name'
      'val.sport'
      'val.website'
    ]
    player: []
    captain: []
    manager: []
    admin: []

  l_roles = get(u2l, 'val.roles') ? []

  fields = reduce(l_roles, ((acc, role) ->
    uniq(union(acc, acl[role])))
  , acl.public)

  league = pick(league, fields)

  l_roles = sortBy(l_roles)
  league = merge(league, {
    val:
      is_admin:   includes(l_roles, 'admin')
      is_captain: includes(l_roles, 'captain')
      is_manager: includes(l_roles, 'manager')
      is_player:  includes(l_roles, 'player')
      roles:      l_roles
  })

  ctx.ok({ league })
  return
