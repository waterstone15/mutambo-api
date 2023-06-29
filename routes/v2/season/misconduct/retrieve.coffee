any          = require 'lodash/some'
log          = require '@/local/lib/log'
{ all }      = require 'rsvp'

MModel       = require '@/local/models/flame-lib/misconduct'
SModel       = require '@/local/models/flame-lib/season'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }           = ctx.state.fbUser
  { misconduct_id } = ctx.request.body
  { season_id }     = ctx.request.body

  Misconduct   = await MModel()
  Season       = await SModel()
  U2S          = await U2SModel()
  User         = await UModel()

  mQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', misconduct_id ]
  ]
  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', season_id ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  mF = [ 'meta.id', 'val.status' ]
  sF = [ 'meta.id' ]
  uF = [ 'meta.id' ]
 
  [ misconduct, season, user ] = await (all [
    Misconduct .find(mQ, mF) .read()
    Season     .find(sQ, sF) .read()
    User       .find(uQ, uF) .read()
  ])

  if (any [ !misconduct, !season, !user ])
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

  (ctx.ok { misconduct })
  return



