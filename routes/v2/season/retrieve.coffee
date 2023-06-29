FLI      = require '@/local/lib/flame-lib-init'
get      = require 'lodash/get'
hash     = require '@/local/lib/hash'
includes = require 'lodash/includes'
merge    = require 'lodash/merge'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
SModel   = require '@/local/models/flame-lib/season'
sortBy   = require 'lodash/sortBy'
U2SModel = require '@/local/models/flame-lib/user-to-season'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  Season = await SModel()
  UserToSeason = await U2SModel()

  user = await User.getByUid(uid)

  u2sQ = [
    [ 'where', 'rel.season', '==', id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ season, user_to_season ] = await all([
    Season.get(id).read()
    UserToSeason.find(u2sQ).read()
  ])

  roles = get(user_to_season, 'val.roles') ? []

  if !season || season.meta.deleted
    ctx.badRequest()
    return

  acl =
    public: [ 'meta.created_at', 'meta.id', 'meta.v', 'val.name', 'val.status', ]
    player: []
    captain: []
    manager: []
    admin: []

  fields = reduce(roles, ((acc, role) ->
    uniq(union(acc, acl[role])))
  , acl.public)

  season = pick(season, fields)

  roles = sortBy(roles)
  season = merge(season, {
    val:
      is_admin:   includes(roles, 'admin')
      is_captain: includes(roles, 'captain')
      is_manager: includes(roles, 'manager')
      is_player:  includes(roles, 'player')
      roles:     roles
  })

  ctx.ok({ season })
  return
