FLI      = require '@/local/lib/flame-lib-init'
get      = require 'lodash/get'
hash     = require '@/local/lib/hash'
ICModel  = require '@/local/models/flame-lib/invite-code'
includes = require 'lodash/includes'
log      = require '@/local/lib/log'
pick     = require 'lodash/pick'
SModel   = require '@/local/models/flame-lib/season'
SSModel  = require '@/local/models/flame-lib/season-settings'
toLower  = require 'lodash/toLower'
trim     = require 'lodash/trim'
U2LModel = require '@/local/models/flame-lib/user-to-league'
U2SModel = require '@/local/models/flame-lib/user-to-season'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  form = ctx.request.body

  if !uid
    ctx.unauthorized()
    return
    
  Flame = await FLI('main')
  
  InviteCode     = await ICModel()
  Season         = await SModel()
  SeasonSettings = await SSModel()
  UserToLeague   = await U2LModel()
  UserToSeason   = await U2SModel()

  user = await User.getByUid(uid, { values: { meta: [ 'id' ], val: [ 'full_name', 'display_name' ] }})
  
  league_id = get(form, 'rel.league')
  season_id = (Season.create().obj().meta.id)

  u2lQ = [
    [ 'where', 'rel.league', '==', league_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2l = await UserToLeague.find(u2lQ).read()
  if !includes(u2l.val.roles, 'owner')
    ctx.unauthorized()
    return

  invite_code_sa = InviteCode.create({
    meta:
      type: 'invite-code/season-admin'
    rel:
      league: league_id
      season: season_id
  })

  invite_code_st = InviteCode.create({
    meta:
      type: 'invite-code/season-team'
    rel:
      league: league_id
      season: season_id
  })

  season_settings = SeasonSettings.create({
    rel: 
      season: season_id
  })
  
  season = Season.create({
    meta:
      id: season_id
    rel:
      league: league_id
      settings: season_settings.obj().meta.id
    val:
      name: trim(get(form, 'val.name'))
  })
  
  user_to_season = UserToSeason.create({
    index:
      user_display_name_insensitive: toLower(trim(user.val.display_name))
      user_full_name_insensitive: toLower(trim(user.val.full_name))
    rel:
      season: season_id
      user: user.meta.id
    val: 
      roles: [ 'admin' ]
  })

  await Flame.transact((_t) ->
    await invite_code_sa.save().write(_t)
    await invite_code_st.save().write(_t)
    await season.save().write(_t)
    await season_settings.save().write(_t)
    await user_to_season.save().write(_t)
    return
  )

  ctx.ok({})
  return

  