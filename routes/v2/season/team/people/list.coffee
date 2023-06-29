get          = require 'lodash/get'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
log          = require '@/local/lib/log'
sortBy       = require 'lodash/sortBy'
{ all }      = require 'rsvp'

U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  { uid }       = ctx.state.fbUser
  { season_id } = ctx.request.body
  { team_id }   = ctx.request.body

  U2S  = await U2SModel()
  U2T  = await U2TModel()
  User = await UModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ, [ 'meta.id' ]).read()

  if !user
    (ctx.badRequest {})
    return

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season_id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', team_id ]
    [ 'where', 'val.roles',    'array-contains-any', [ 'manager', 'player' ]]
    [ 'select', 'rel.user' ]
  ]

  u2sF = [ 'meta.id', 'val.roles' ]

  [ u2s, u2ts, ] = await (all [
    U2S .find(u2sQ, u2sF) .read()
    U2T .list(u2tsQ)      .read()
  ])

  if !u2s
    (ctx.badRequest {})
    return

  uids   = (map u2ts, (_u2t) -> _u2t.rel.user)
  uF     = [ 'meta.id', 'val.full_name' ]
  people = await User.getAll(uids, uF).read()
  people = (sortBy people, 'val.full_name')

  (ctx.ok { people })
  return
