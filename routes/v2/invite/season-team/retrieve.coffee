hash         = require '@/local/lib/hash'
ICModel      = require '@/local/models/flame-lib/invite-code'
includes     = require 'lodash/includes'
LModel       = require '@/local/models/flame-lib/league'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
SModel       = require '@/local/models/flame-lib/season'
SSModel      = require '@/local/models/flame-lib/season-settings'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { code } = ctx.request.body

  InviteCode     = await ICModel()
  League         = await LModel()
  Season         = await SModel()
  SeasonSettings = await SSModel()
  UserToSeason   = await U2SModel()

  il_query = [
    [ 'where', 'val.code', '==', code ]
    [ 'where', 'meta.type', '==', 'invite-code/season-team' ]
  ]

  [ invite_code, user ] = await all([
    InviteCode.find(il_query).read()
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

  ssQ = [[ 'where', 'rel.season', '==', invite_code.rel.season ]]
  u2sQ = [
    [ 'where', 'rel.season', '==', invite_code.rel.season ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ league, season, settings, user_to_season ] = await all([
    League.get(invite_code.rel.league).read()
    Season.get(invite_code.rel.season).read()
    SeasonSettings.find(ssQ).read()
    UserToSeason.find(u2sQ).read()
  ])

  if (season.meta.deleted || season.val.status != 'active')
    ctx.badRequest({})
    return

  league = pick(league, [ 'meta.id', 'val.name' ])
  season = pick(season, [ 'meta.id', 'val.name' ])
  season = merge(season, {
    val:
      is_admin: (user_to_season && includes(user_to_season.val.roles, 'admin'))
  })
  settings = pick(settings, [ 'val.required_info.manager', 'val.registration_status.team_season' ])

  ctx.ok({ league, season, settings })
  return
