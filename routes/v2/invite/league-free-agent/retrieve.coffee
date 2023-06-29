hash         = require '@/local/lib/hash'
ICModel      = require '@/local/models/flame-lib/invite-code'
includes     = require 'lodash/includes'
LModel       = require '@/local/models/flame-lib/league'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
SModel       = require '@/local/models/flame-lib/season'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { code } = ctx.request.body

  InviteCode   = await ICModel()
  League       = await LModel()

  ilQ = [
    [ 'where', 'val.code', '==', code ]
    [ 'where', 'meta.type', '==', 'invite-code/league-free-agent' ]
  ]
  
  [ invite_code, user ] = await all([
    InviteCode.find(ilQ).read()
    User.getByUid(uid)
  ])

  if !user
    ctx.badRequest({})
    return

  now = DateTime.local().setZone('utc')
  { expires_at } = invite_code.val

  if (
    (!invite_code) ||
    (invite_code.meta.deleted) ||
    (invite_code.val.uses > invite_code.val.max_uses) ||
    (expires_at && (now > DateTime.fromISO(expires_at)))
  )
    ctx.badRequest({})
    return

  [ league ] = await all([
    League.get(invite_code.rel.league).read()
  ])

  if (!league || league.meta.deleted)
    ctx.badRequest({})
    return

  league = pick(league, [ 'meta.id', 'val.name' ])

  ctx.ok({ league })
  return
