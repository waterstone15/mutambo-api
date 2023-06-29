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
  season_id = notification.rel.season

  authorized= await SeasonToUser.anyRole({ season: { meta: { id: season_id }}, user, roles: [ 'admin' ] })

  if !authorized || !notification
    ctx.unauthorized()
    return

  updates = []
  updates.push({ t: 'update', p: "/notifications", d: "#{notification_id}", o: { 'val-status': 'complete' }})

  wb = db.batch()
  for u in updates
    wb[u.t](db.collection(u.p).doc(u.d), u.o)
  await wb.commit()

  ctx.ok({})
  return
