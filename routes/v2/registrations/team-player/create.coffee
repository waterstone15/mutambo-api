any          = require 'lodash/some'
each         = require 'lodash/each'
filter       = require 'lodash/filter'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
includes     = require 'lodash/includes'
keys         = require 'lodash/keys'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
omit         = require 'lodash/omit'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
without      = require 'lodash/without'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

ICModel  = require '@/local/models/flame-lib/invite-code'
LModel   = require '@/local/models/flame-lib/league'
PModel   = require '@/local/models/flame-lib/payment'
RModel   = require '@/local/models/flame-lib/registration'
SModel   = require '@/local/models/flame-lib/season'
SSModel  = require '@/local/models/flame-lib/season-settings'
TModel   = require '@/local/models/flame-lib/team'
U2LModel = require '@/local/models/flame-lib/user-to-league'
U2SModel = require '@/local/models/flame-lib/user-to-season'
U2TModel = require '@/local/models/flame-lib/user-to-team'
UModel   = require '@/local/models/flame-lib/user'


ite = (c, a, b = null) -> if c then a else b

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { form, code } = ctx.request.body
  
  if !uid
    (ctx.unauthorized {})
    return

  Flame = await (FLI 'main')
  db    = await Flame.wildfire().firestore()
  
  IC           = await ICModel()
  League       = await LModel()
  Payment      = await PModel()
  Registration = await RModel()
  Season       = await SModel()
  SS           = await SSModel()
  Team         = await TModel()
  U2L          = await U2LModel()
  U2S          = await U2SModel()
  U2T          = await U2TModel()
  User         = await UModel()


  icQ = [
    [ 'where', 'val.code', '==', code ]
    [ 'where', 'meta.type', '==', 'invite-code/team-player' ]
  ]
  
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  [ ic, user ] = await (all [
    (IC  .find(icQ).read())
    (User.find(uQ) .read())
  ])

  now = DateTime.local().setZone('utc')
  { expires_at } = ic.val

  if (any [
    (!ic)
    (!user)
    (ic.meta.deleted)
    (user.meta.deleted)
    (expires_at && (now > DateTime.fromISO(expires_at)))
    (ic.val.uses > ic.val.max_uses)
  ])
    (ctx.badRequest {})
    return

  pcQ = [
    [ 'where', 'rel.team',  '==', ic.rel.team  ]
    [ 'where', 'val.roles', 'array-contains', 'player' ]
  ]
  
  rQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.type',    '==', 'registration/team-player' ]
    [ 'where', 'rel.team',     '==', ic.rel.team  ]
    [ 'where', 'rel.user',     '==', user.meta.id  ]
  ]

  ssQ = [
    [ 'where', 'rel.season', '==', ic.rel.season  ]
  ]

  u2lQ = [
    [ 'where', 'rel.league', '==', ic.rel.league ]
    [ 'where', 'rel.user',   '==', user.meta.id  ]
  ]
  u2sQ = [
    [ 'where', 'rel.season', '==', ic.rel.season ]
    [ 'where', 'rel.user',   '==', user.meta.id  ]
  ]
  u2tQ = [
    [ 'where', 'rel.team',   '==', ic.rel.team  ]
    [ 'where', 'rel.user',   '==', user.meta.id ]
  ]

  [ league, player_count, registration, season, ss, team, u2l, u2s, u2t ] = await (all [
    League       .get(ic.rel.league) .read()
    U2T          .count(pcQ)         .read()
    Registration .find(rQ)           .read()
    Season       .get(ic.rel.season) .read()
    SS           .find(ssQ)          .read()
    Team         .get(ic.rel.team)   .read()
    U2L          .find(u2lQ)         .read()
    U2S          .find(u2sQ)         .read()
    U2T          .find(u2tQ)         .read()
  ])

  if registration
    (ctx.ok {})
    return

  if (any [
    (!team)
    ((get ss, 'val.registration_status.player_team') == 'closed')
    (player_count >= ((get ss, 'val.team_limits.team_players') ? 0))
    (league && league.meta.deleted)
    (season && season.meta.deleted)
    (team   && team.meta.deleted)
  ])
    (ctx.badRequest {})
    return

  
  required    = ss.val.required_info.player
  user_fields = (filter (map required, (_v, _k) -> if _v then "#{_k}" else null))
  user_info   = (pick form, user_fields)
  user_paths  = (map user_fields, (_f) -> "val.#{_f}")

  user_old = user

  user = (User.create (merge user_old, {
    val: (merge user_info, { email: user_old.val.email })
  }))

  if !(user.ok user_fields)
    (ctx.badRequest {})
    return
  
  registration_id = (Registration.create {}).obj().meta.id

  registration = (Registration.create {
    meta:
      id: registration_id
      type: 'registration/team-player'
    rel:
      league:          league.meta.id
      payment:         null
      season:          season.meta.id
      season_settings: ss.meta.id
      team:            team.meta.id
      user:            user.obj().meta.id
    val:
      completed_at:    DateTime.local().setZone('utc').toISO()
      form:            form
      status:          'complete'
  })
  r_status = registration.obj().val.status


  u2l = (U2L.create (merge (if u2l then u2l else {}), {
    index:
      user_display_name_insensitive: (toLower (trim user.obj().val.display_name))
      user_full_name_insensitive:    (toLower (trim user.obj().val.full_name))
    rel:
      league: league.meta.id
      user:   user.obj().meta.id
    val: 
      roles: (uniq (union (get u2l, 'val.roles'), [ 'player' ]))
  }))
  
  u2s = (U2S.create (merge (if u2s then u2s else {}), {
    index:
      user_display_name_insensitive: (toLower (trim user.obj().val.display_name))
      user_full_name_insensitive:    (toLower (trim user.obj().val.full_name))
    rel:
      season: season.meta.id
      user:   user.obj().meta.id
    val: 
      roles: (uniq (union (get u2s, 'val.roles'), [ 'player' ]))
  }))

  role_event = [{
    update:     'player:added'
    updated_at: registration.obj().meta.created_at
  }]
  u2t = (U2T.create (merge {}, (ite u2t, u2t, {}), {
    index:
      user_display_name_insensitive: (toLower (trim user.obj().val.display_name))
      user_full_name_insensitive:    (toLower (trim user.obj().val.full_name))
    rel:
      league: league.meta.id
      season: season.meta.id
      team:   team.meta.id
      user:   user.obj().meta.id
    val: 
      role_history: if u2t then (union [], u2t.val.role_history, role_event) else role_event
      roles:        (uniq (union (get u2t, 'val.roles'), [ 'player' ]))
  }))
  

  u2x_paths = [
    'index.user_display_name_insensitive'
    'index.user_full_name_insensitive'
    'val.role_history'
    'val.roles'
  ]

  if (any [
    (!(registration.ok()))
    (!(user.ok user_paths))
    (!(u2l.ok (ite u2l, u2x_paths)) && (r_status == 'complete'))
    (!(u2s.ok (ite u2s, u2x_paths)) && (r_status == 'complete'))
    (!(u2t.ok (ite u2t, u2x_paths)) && (r_status == 'complete'))
  ])
    (ctx.badRequest {})
    return

  ok = await (Flame.transact (_t) ->
    [ ul, us, ut, ] = await (all [
      (U2L.find u2lQ).read(_t)
      (U2S.find u2sQ).read(_t)
      (U2T.find u2tQ).read(_t)
    ])
    (u2l = (U2L.create (merge u2l.obj(), { meta: { id: ul.meta.id }}))) if !!(get ul, 'meta.id')
    (u2s = (U2S.create (merge u2s.obj(), { meta: { id: us.meta.id }}))) if !!(get us, 'meta.id')
    (u2t = (U2T.create (merge u2t.obj(), { meta: { id: ut.meta.id }}))) if !!(get ut, 'meta.id')

    await registration.save().write(_t)
    await user.update(user_paths).write(_t)
    return true if (r_status != 'complete')

    await u2l[(ite ul, 'update', 'save')]((ite ul, u2x_paths)).write(_t)
    await u2s[(ite us, 'update', 'save')]((ite us, u2x_paths)).write(_t)
    await u2t[(ite ut, 'update', 'save')]((ite ut, u2x_paths)).write(_t)
    return true
  )

  r = (ite ok, 'ok', 'badRequest')
  (ctx[r] {})
  return