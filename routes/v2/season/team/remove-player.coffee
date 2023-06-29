any          = require 'lodash/some'
clone        = require 'lodash/clone'
FLI          = require '@/local/lib/flame-lib-init'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
uniq         = require 'lodash/uniq'
without      = require 'lodash/without'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

SSModel   = require '@/local/models/flame-lib/season-settings'
TModel    = require '@/local/models/flame-lib/team'
U2LModel  = require '@/local/models/flame-lib/user-to-league'
U2SModel  = require '@/local/models/flame-lib/user-to-season'
U2TModel  = require '@/local/models/flame-lib/user-to-team'
UModel    = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  form    = ctx.request.body

  player_id = form.meta.id
  season_id = form.rel.season
  team_id   = form.rel.team

  Flame = await (FLI 'main')

  SS    = await SSModel()
  Team  = await TModel()
  U2L   = await U2LModel()
  U2S   = await U2SModel()
  U2T   = await U2TModel()
  User  = await UModel()

  p2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', team_id ]
    [ 'where', 'rel.user',     '==', player_id ]
    [ 'where', 'val.roles',    'array-contains', 'player' ]
  ]
  pQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', player_id ]
  ]
  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', team_id ]
    [ 'where', 'rel.season',   '==', season_id ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  
  p2tF = [ 'meta.id', 'rel.team', 'rel.user', 'val.roles' ]
  pF   = [ 'meta.id', ]
  tF   = [ 'meta.id', 'rel.league', 'rel.season',  ]
  uF   = [ 'meta.id', ]

  [ p2t, player, team, user, ] = await (all [
    U2T  .find(p2tQ, p2tF) .read()
    User .find(pQ, pF)     .read()
    Team .find(tQ, tF)     .read()
    User .find(uQ, uF)     .read()
  ])

  if (any [ !p2t, !player, !team, !user, ])
    (ctx.badRequest {})
    return

  p2lQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.league',   '==', team.rel.league ]
    [ 'where', 'rel.user',     '==', player.meta.id ]
  ]
  p2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', team.rel.season ]
    [ 'where', 'rel.user',     '==', player.meta.id ]
  ]
  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', team.rel.season ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]

  pltsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.league',   '==', team.rel.league ]
    [ 'where', 'rel.user',     '==', player.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'player' ]
  ]
  pstsQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user',     '==', player.meta.id ]
    [ 'where', 'rel.season',   '==', team.rel.season ]
    [ 'where', 'val.roles',    'array-contains', 'player' ]
  ]

  p2lF = [ 'meta.id', 'val.roles', ]
  p2sF = [ 'meta.id', 'val.roles', ]
  u2sF = [ 'meta.id', 'val.roles', ]

  [ p2l, p2s, u2s, player_league_team_count, player_season_team_count ] = await (all [
    U2L .find(p2lQ, p2lF) .read()
    U2S .find(p2sQ, p2sF) .read()
    U2S .find(u2sQ, u2sF) .read()
    U2L .count(pltsQ)     .read()
    U2S .count(pstsQ)     .read()
  ])

  if (any [ !p2l, !p2s, !u2s ])
    (ctx.badRequest {})
    return

  # # 1. Remove the UserToTeam 'player' role IFF
  # #   * This player has not been rostered on any game for this team
  # # 
  # # 2. Remove the UserToSeason 'player' role IFF
  # #   * 1. == true AND this player is not a player on any other teams in this league. 
  # # 
  # # 3. Remove the UserToLeague 'player' role IFF
  # #   * 2. == true and this player is not on any other teams in this league 
  # # 
  # # 4. Delete the UserToTeam model IFF
  # #   * There are no roles left on this model.
  # # 
  # # 5. Delete the UserToSeason model IFF
  # #   * There are no roles left on this model.
  # # 
  # # 6. Delete the UserToLeague model IFF
  # #   * There are no roles left on this model.
  # # 
  # now = DateTime.local().setZone('utc').toISO()

  # update = { roles: {}}
  # update.roles.p2t = true
  # update.roles.p2s = (update.roles.p2t && (player_season_team_count <= 1))
  # update.roles.p2l = (update.roles.p2s && (player_league_team_count <= 1))
  
  # p2l.val.roles = (uniq (without p2l.val.roles, 'player')) if update.roles.p2l
  # p2s.val.roles = (uniq (without p2s.val.roles, 'player')) if update.roles.p2s
  # p2t.val.roles = (uniq (without p2t.val.roles, 'player')) if update.roles.p2t

  # p2l.meta.deleted = (isEmpty p2l.val.roles)
  # p2s.meta.deleted = (isEmpty p2s.val.roles)
  # p2t.meta.deleted = (isEmpty p2t.val.roles)
  # p2l.meta.deleted_at = if (isEmpty p2l.val.roles) then now else null
  # p2s.meta.deleted_at = if (isEmpty p2s.val.roles) then now else null
  # p2t.meta.deleted_at = if (isEmpty p2t.val.roles) then now else null

  # p2l = (U2L.create p2l)
  # p2s = (U2S.create p2s)
  # p2t = (U2T.create p2t)

  # fields = [ 'val.roles', 'meta.deleted', 'meta.deleted_at' ]
  
  # if (any [
  #   (update.roles.p2s && !(p2s.ok fields))
  #   (update.roles.p2t && !(p2t.ok fields))
  #   (update.roles.p2l && !(p2l.ok fields))
  # ])
  #   (ctx.badRequest {})
  #   return

  # ok = await (Flame.transact (_t) ->
  #   await p2l.update(fields).write(_t)
  #   await p2s.update(fields).write(_t)
  #   await p2t.update(fields).write(_t)
  #   return true
  # )

  # switch ok
  #   when true then (ctx.ok {})
  #   else (ctx.badRequest {})
  (ctx.ok {})
  return
