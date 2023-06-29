hash     = require '@/local/lib/hash'
ICModel  = require '@/local/models/flame-lib/invite-code'
isEmpty  = require 'lodash/isEmpty'
log      = require '@/local/lib/log'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
U2LModel = require '@/local/models/flame-lib/user-to-league'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { league_id } = ctx.request.body

  InviteCode   = await ICModel()
  UserToLeague = await U2LModel()

  user = await User.getByUid(uid)

  icQ = [
    [ 'where', 'rel.league', '==', league_id ]
    [ 'where', 'meta.type', '==', 'invite-code/league-free-agent' ]
  ]
  u2lQ = [
    [ 'where', 'rel.league', '==', league_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ invite_code, user_to_league ] = await all([
    InviteCode.find(icQ).read()
    UserToLeague.find(u2lQ).read()
  ])

  if !user_to_league || user_to_league.meta.deleted || !invite_code
    ctx.badRequest()
    return

  acl =
    public: []
    player: []
    captain: []
    manager: []
    admin: [ 'meta.id', 'meta.type', 'val.code', ]

  fields = reduce(user_to_league.val.roles, ((acc, role) ->
    uniq(union(acc, acl[role])))
  , acl.public)

  invite_code = pick(invite_code, fields)
  (invite_code = null) if isEmpty(invite_code)

  ctx.ok({ invite_code })
  return
