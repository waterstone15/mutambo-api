any          = require 'lodash/some'
curryRight   = require 'lodash/curryRight'
every        = require 'lodash/every'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
isMatch      = require 'lodash/isMatch'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
matches      = require 'lodash/matches'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
{ all }      = require 'rsvp'

SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }       = ctx.state.fbUser
  { season_id } = ctx.request.body
  { team_id }   = ctx.request.body

  Season = await SModel()
  Team   = await TModel()
  U2S    = await U2SModel()
  U2T    = await U2TModel()
  User   = await UModel()

  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', season_id ]
  ]
  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', team_id ]
  ]
  u2tsQ = [
    [ 'where', 'rel.team', '==', team_id ]
    [ 'select', 'meta.id', 'rel.user', 'val.roles', 'val.role_history' ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  sF = [ 'meta.id' ]
  tF = [ 'meta.id', 'val.name' ]
  uF = [ 'meta.id' ]
 
  [ season, team, u2ts, user ] = await (all [
    Season .find(sQ, sF) .read()
    Team   .find(tQ, tF) .read()
    U2T    .list(u2tsQ)  .read()
    User   .find(uQ, uF) .read()
  ])

  if (any [ !season, !team, !user ])
    (ctx.badRequest {})
    return

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season.meta.id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2sF = [ 'meta.id' ]

  u2s = await U2S.find(u2sQ, u2sF).read()

  if !u2s
    (ctx.badRequest {})
    return

  uids  = (map u2ts, 'rel.user')
  usF   = [ 'meta.id', 'val.birthday', 'val.display_name', 'val.email', 'val.full_name',]

  users = await User.getAll(uids, usF).read()
  users = (map users, (_u) ->
    u2t  = (find u2ts, { rel: user: _u.meta.id })
    u2tF = [ 'val.roles', 'val.role_history', ]
    uF   = [ 'meta.id', 'val.email', 'val.display_name', 'val.full_name', 'val.roles', 'val.role_history' ]
    return (merge {}, (pick _u, uF), (pick u2t, ), {
      val:
        is_manager: (includes u2t.val.roles, 'manager')
        is_player:  (includes u2t.val.roles, 'player')
        is_manager_rm: (every [
          !(includes u2t.val.roles, 'manager')
          !(isEmpty (filter u2t.val.role_history, (matches { update: 'manager:added' })))
        ])
        is_player_rm:  (every [
          !(includes u2t.val.roles, 'player')
          !(isEmpty (filter u2t.val.role_history, (matches { update: 'player:added' })))
        ])
    })
  )
  users = (sortBy users, ((_u) -> "#{(toLower _u.val.full_name)}-#{(toLower _u.val.display_name)}"))

  team = (merge {}, team, {
    val:
      managers:    (filter users, (matches { val: { is_manager: true }}))
      managers_rm: (filter users, (matches { val: { is_manager_rm: true }}))
      players:     (filter users, (matches { val: { is_player: true }}))
      players_rm:  (filter users, (matches { val: { is_player_rm: true }}))
  })

  (ctx.ok { team })
  return



