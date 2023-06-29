blackout     = require '@/local/lib/blackout'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
toLower      = require 'lodash/toLower'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id, suspensions } = ctx.request.body

  [ fba, season, user ] = await all([
    fbaI()
    fbaH.get('/seasons', season_id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  rolesDS = await db.collection("/seasons/#{season.meta.id}/users").doc(user.meta.id).get()
  roles   = rolesDS.data()['access-control']
  if !includes(roles, 'admin')
    ctx.unauthorized()
    return

  now = DateTime.local().setZone('utc')

  if !season || !user
    ctx.badRequest()
    return

  misconducts = map(suspensions, (s) ->
    return merge(s, {
      meta:
        created_at: now.toISO()
        deleted: false
        id: "misconduct-#{db.collection('/misconducts').doc().id}"
        type: 'misconduct'
        updated_at: now.toISO()
        v: 2
      rel:
        game: null
        league: season.rel.league
        season: season.meta.id
      val:
        suspended_at: now.toISO() # the iso timestamp of when the suspension started
        reinstated_at: null # the iso timestamp of when the suspension ended
        notes: ''
        status: 'suspended' # 'suspended' | 'reinstated'

    })
  )

  await all(map(misconducts, (m) ->
    obj = fbaH.serialize(m)
    await db.collection('/misconducts').doc(m.meta.id).set(obj)
    return
  ))

  ctx.ok({})
  return
