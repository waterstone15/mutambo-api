fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
map          = require('lodash/map')
merge        = require('lodash/merge')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: meta: [ 'id' ] })
  ])

  db = fba.firestore()

  leagues = []

  leagueIDsQS = await db.collection("/users/#{user.meta.id}/leagues").get()
  leagues = await all(map(leagueIDsQS.docs, (doc) ->
    rolesDS  = await db.collection("/leagues/#{doc.id}/users").doc(user.meta.id).get()
    leagueDS = await db.collection('/leagues').doc(doc.id).get()
    league   = fbaHelpers.deserialize(leagueDS.data())
    return merge(league, {
      val:
        roles: if rolesDS.exists then (rolesDS.data()['access-control'] ? []) else []
    })
  ))

  _2021 = DateTime.fromISO('2021-01-01')

  leagues = filter(leagues, (_l) ->
    return _l.meta.id == 'fARwSinLZ1GQffbxqEfo' ||  DateTime.fromISO(_l.meta.created_at) > _2021
  )

  ctx.ok({ leagues })
  return
