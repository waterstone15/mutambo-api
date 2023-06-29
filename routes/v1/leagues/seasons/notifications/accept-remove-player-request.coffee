fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
Notification = require '@/local/models/flame/notification'
pick         = require 'lodash/pick'
SeasonToUser = require '@/local/models/season-to-user'
Team         = require '@/local/models/flame/team'
uniq         = require 'lodash/uniq'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { notification_id  } = ctx.request.body

  fba = await fbaI()
  db  = fba.firestore()

  [ user, notification ] = await all([
    User.getByUid(uid, { values: { meta: ['id'] }})
    Notification.get(notification_id)
  ])
  player_id = notification.val.data.rel.player
  season_id = notification.rel.season
  team_id   = notification.val.data.rel.team


  P1 = ->
    QS1 = await db.collection("/users/#{player_id}/teams").get()

    teams = await all(map((QS1.docs ? []), (DS) ->
      [ teamDS, rolesDS ] = await all([
        db.collection("/teams/").doc(DS.id).get()
        db.collection("/teams/#{DS.id}/users").doc(player_id).get()
      ])
      return pick(merge(teamDS.data(), { 'val-roles': rolesDS.data()['access-control'] ? [] }), [ 'meta-id', 'val-roles', 'rel-season' ])
    ))
    teams = filter(teams, (t) -> t['rel-season'] == season_id)

    team_roles = uniq(find(teams, { 'meta-id': team_id })['val-roles'])
    season_teams_as_player = filter(teams, (t) -> includes(t['val-roles'], 'player'))

    return { team_roles, season_teams_as_player }


  [ authorized, { team_roles, season_teams_as_player }, season_to_user ] = await all([
    SeasonToUser.anyRole({ season: { meta: { id: season_id }}, user, roles: [ 'admin' ] })
    P1()
    SeasonToUser.findOne({ season: { meta: { id: season_id }}, user })
  ])

  if !authorized || !notification
    ctx.unauthorized()
    return


  updates = []
  updates.push({ t: 'update', p: "/notifications", d: "#{notification_id}", o: { 'val-status': 'complete' }})
  updates.push({ t: 'update', p: "/teams", d: "#{team_id}", o: { 'val-player-count': fba.firestore.FieldValue.increment(-1) }})

  if season_teams_as_player.length <= 1
    updates.push({ t: 'update', p: "/seasons/#{season_id}/users", d: "#{player_id}", o: { 'access-control': fba.firestore.FieldValue.arrayRemove('player') }})
    updates.push({ t: 'update', p: "/seasons-to-users", d: "#{season_to_user.meta.id}", o: { 'val-access-control': fba.firestore.FieldValue.arrayRemove('player') }})

  if team_roles.length <= 1
    updates.push({ t: 'delete', p: "/teams/#{team_id}/users", d: "#{player_id}", o: {}})
    updates.push({ t: 'delete', p: "/users/#{player_id}/teams", d: "#{team_id}", o: {}})
  else
    updates.push({ t: 'update', p: "/teams/#{team_id}/users", d: "#{player_id}", o: { 'access-control': fba.firestore.FieldValue.arrayRemove('player') }})

  wb = db.batch()
  for u in updates
    wb[u.t](db.collection(u.p).doc(u.d), u.o)
  await wb.commit()

  ctx.ok({})
  return
