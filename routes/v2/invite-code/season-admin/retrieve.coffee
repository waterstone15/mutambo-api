FLI      = require '@/local/lib/flame-lib-init'
hash     = require '@/local/lib/hash'
ICModel  = require '@/local/models/flame-lib/invite-code'
log      = require '@/local/lib/log'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
SSModel  = require '@/local/models/flame-lib/season-settings'
U2SModel = require '@/local/models/flame-lib/user-to-season'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id } = ctx.request.body

  InviteCode   = await ICModel()
  UserToSeason = await U2SModel()

  user = await User.getByUid(uid)

  icQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'meta.type', '==', 'invite-code/season-admin' ]
  ]
  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ invite_code, user_to_season ] = await all([
    InviteCode.find(icQ).read()
    UserToSeason.find(u2sQ).read()
  ])

  if !user_to_season || user_to_season.meta.deleted || !invite_code
    ctx.badRequest()
    return

  acl =
    public: []
    player: []
    captain: []
    manager: []
    admin: [ 'meta.id', 'meta.type', 'val.code', ]

  fields = reduce(user_to_season.val.roles, ((acc, role) ->
    uniq(union(acc, acl[role])))
  , acl.public)

  invite_code = pick(invite_code, fields)

  ctx.ok({ invite_code })
  return
