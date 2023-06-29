fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
Notification = require '@/local/models/flame/notification'
SeasonToUser = require '@/local/models/season-to-user'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { end_before, search_at, season_id, start_after, } = ctx.request.body

  fba = await fbaI()
  db  = fba.firestore()

  P1 = ->
    user = await User.getByUid(uid, { values: { meta: ['id'] }})
    authorized = await SeasonToUser.anyRole({
      season: { meta: { id: season_id }}
      user
      roles: [ 'admin' ]
    })
    return { user, authorized }

  [ season, { user, authorized } ] = await all([
    fbaH.get('/seasons', season_id)
    P1()
  ])

  if !authorized
    ctx.unauthorized()
    return

  if !season || !user
    ctx.badRequest()
    return

  notifications = await Notification.list([
    [ 'where', 'rel-season', '==', season_id ]
    [ 'where', 'val-status', '==', 'to-do' ]
  ])

  ctx.ok(notifications)
  return
