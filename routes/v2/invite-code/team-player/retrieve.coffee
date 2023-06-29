ICModel  = require '@/local/models/flame-lib/invite-code'
isEmpty  = require 'lodash/isEmpty'
log      = require '@/local/lib/log'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
U2TModel = require '@/local/models/flame-lib/user-to-team'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid }     = ctx.state.fbUser
  { team_id } = ctx.request.body

  IC  = await ICModel()
  U2T = await U2TModel()

  user = await (User.getByUid uid)

  icQ = [
    [ 'where', 'meta.type', '==', 'invite-code/team-player' ]
    [ 'where', 'rel.team', '==', team_id ]
  ]
  u2tQ = [
    [ 'where', 'rel.team', '==', team_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ invite_code, user_to_team ] = await (all [
    (IC.find icQ).read()
    (U2T.find u2tQ).read()
  ])

  if !user_to_team || user_to_team.meta.deleted || !invite_code
    (ctx.badRequest {})
    return

  acl =
    player: []
    captain: []
    manager: [ 'meta.id', 'meta.type', 'val.code' ]

  fields = (reduce user_to_team.val.roles, ((acc, role) ->
    return (uniq (union acc, acl[role])))
  , [])

  invite_code = (pick invite_code, fields)
  (invite_code = null) if (isEmpty invite_code)

  (ctx.ok { invite_code })
  return
