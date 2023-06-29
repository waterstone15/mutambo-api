castArray    = require 'lodash/castArray'
compact      = require 'lodash/compact'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

UModel       = require '@/local/models/flame-lib/user'
U2LModel     = require '@/local/models/flame-lib/user-to-league'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { full_name } = ctx.request.body

  User = await UModel()
  U2L  = await U2LModel()
  U2S  = await U2SModel()
  U2T  = await U2TModel()

  full_name = (trim full_name) || null
  full_name_insensitive = (toLower full_name) || ''

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  uF = [ 'meta.id', 'val.full_name', 'val.full_name_history' ]
 
  user = await User.find(uQ, uF).read()
  old_name = (trim user.val.full_name) || null
  
  if !user
    (ctx.badRequest {})
    return

  if old_name == full_name
    (ctx.ok {})
    return

  history = (union (compact (castArray user.val.full_name_history)), [{
    full_name:  full_name
    created_at: DateTime.local().setZone('utc').toISO()
  }])
  
  _user = (User.create (merge user, {
    val:
      full_name: full_name
      full_name_history: history
  }))

  user_fields    = [ 'val.full_name', 'val.full_name_history' ]
  user_to_fields = [ 'index.user_full_name_insensitive' ]

  if !(_user.ok user_fields)
    (ctx.badRequest {})
    return

  u2lsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    [ 'select', 'meta.id' ]
  ]
  u2ssQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    [ 'select', 'meta.id' ]
  ]
  u2tsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    [ 'select', 'meta.id' ]
  ]

  [ u2ls, u2ss, u2ts ] = await (all [
    U2L.list(u2lsQ).read()
    U2S.list(u2ssQ).read()
    U2T.list(u2tsQ).read()
  ])

  P1 = ->
    await (all (map u2ls, (_u2l) ->
      u2l = (U2L.create (merge _u2l, {
        index:
          user_full_name_insensitive: full_name_insensitive
      }))
      await u2l.update([ 'index.user_full_name_insensitive' ]).write()
      return
    ))
    return

  P2 = ->
    await (all (map u2ss, (_u2s) ->
      u2s = (U2S.create (merge _u2s, {
        index:
          user_full_name_insensitive: full_name_insensitive
      }))
      await u2s.update([ 'index.user_full_name_insensitive' ]).write()
      return
    ))
    return

  P3 = ->
    await (all (map u2ts, (_u2t) ->
      u2t = (U2T.create (merge _u2t, {
        index:
          user_full_name_insensitive: full_name_insensitive
      }))
      await u2t.update([ 'index.user_full_name_insensitive' ]).write()
      return
    ))
    return

  await (all [
    P1()
    P2()
    P3()
    _user.update(user_fields).write()
  ])

  (ctx.ok {})
  return


