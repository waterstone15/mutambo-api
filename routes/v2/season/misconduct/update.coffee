any          = require 'lodash/some'
every        = require 'lodash/every'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

MModel       = require '@/local/models/flame-lib/misconduct'
SModel       = require '@/local/models/flame-lib/season'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }     = ctx.state.fbUser
  _m = ctx.request.body

  Misconduct   = await MModel()
  Season       = await SModel()
  U2S          = await U2SModel()
  User         = await UModel()

  mQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', _m.meta.id ]
  ]
  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', _m.rel.season ]
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

  if (any [ !misconduct, !season, !misconduct ])
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

  fields = [ 'val.status', 'val.suspension_end_utc' ]

  m = (Misconduct.create (merge {}, misconduct, _m, {
    val:
      suspension_end_utc: DateTime.local().setZone('utc').toISO()
  }))

  if (every [
    (_m.val.status == 'resolved')
    (m.ok fields)
    (misconduct.val.status != 'resolved')
  ])
    await m.update(fields).write()

  (ctx.ok {})
  return



