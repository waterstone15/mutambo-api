any          = require 'lodash/some'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
ICModel      = require '@/local/models/flame-lib/invite-code'
includes     = require 'lodash/includes'
LModel       = require '@/local/models/flame-lib/league'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
SModel       = require '@/local/models/flame-lib/season'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
U2LModel     = require '@/local/models/flame-lib/user-to-league'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


ite = (c, a, b = null) -> if c then a else b

module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { code } = ctx.request.body

  Flame = await (FLI 'main')

  InviteCode   = await ICModel()
  League       = await LModel()
  Season       = await SModel()
  UserToLeague = await U2LModel()
  UserToSeason = await U2SModel()


  ic_query = [
    [ 'where', 'val.code', '==', code ]
    [ 'where', 'meta.type', '==', 'invite-code/season-admin' ]
  ]

  [ invite_code, user ] = await all([
    (InviteCode.find ic_query).read()
    (User.getByUid uid)
  ])

  if !user
    (ctx.badRequest {})
    return


  now = DateTime.local().setZone('utc')
  { expires_at } = invite_code.val

  if (any([
    (!invite_code)
    (invite_code.meta.deleted)
    (invite_code.val.uses > invite_code.val.max_uses)
    (expires_at && (now > (DateTime.fromISO expires_at)))
  ]))
    (ctx.badRequest {})
    return

  [ league, season,  ] = await all([
    (League.get invite_code.rel.league).read()
    (Season.get invite_code.rel.season).read()
  ])

  if (season.meta.deleted || season.val.status != 'active')
    (ctx.badRequest {})
    return


  u2lQ = [
    [ 'where', 'rel.league', '==', invite_code.rel.league ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2l = await (UserToLeague.find u2lQ).read()
  u2l_roles = (get u2l, 'val.roles') ? []
  user_to_league = (UserToLeague.create {
    index:
      user_display_name_insensitive: (toLower (trim user.val.display_name))
      user_full_name_insensitive:    (toLower (trim user.val.full_name))
    rel:
      league: invite_code.rel.league
      user:   user.meta.id
    val: 
      roles: (uniq (union u2l_roles, [ 'admin' ]))
  })

  u2sQ = [
    [ 'where', 'rel.season', '==', invite_code.rel.season ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2s = await (UserToSeason.find u2sQ).read()
  u2s_roles = (get u2s, 'val.roles') ? []
  user_to_season = (UserToSeason.create {
    index:
      user_display_name_insensitive: (toLower (trim user.val.display_name))
      user_full_name_insensitive:    (toLower (trim user.val.full_name))
    rel:
      season: invite_code.rel.season
      user:   user.meta.id
    val: 
      roles: (uniq (union u2s_roles, [ 'admin' ]))
  })

  u2x_paths = [
    'index.user_display_name_insensitive'
    'index.user_full_name_insensitive'
    'val.roles'
  ]

  if any([
    (!user_to_league.ok (ite u2l, u2x_paths))
    (!user_to_season.ok (ite u2s, u2x_paths))
  ])
    (ctx.badRequest {})
    return

  ok = await (Flame.transact (_t) ->
    await user_to_league[(ite u2l, 'update', 'save')](ite u2l, u2x_paths).write(_t)
    await user_to_season[(ite u2s, 'update', 'save')](ite u2s, u2x_paths).write(_t)
    return true
  )

  if !ok
    (ctx.badRequest {})
    return
  
  (ctx.ok {})
  return
