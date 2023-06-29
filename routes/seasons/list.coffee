fbaInit      = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
intersection = require('lodash/intersection')
isEmpty      = require('lodash/isEmpty')
map          = require('lodash/map')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
sortBy       = require('lodash/sortBy')
union        = require('lodash/union')
unionBy      = require('lodash/unionBy')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: [] })
  ])

  db = fba.firestore()

  leagueIDs = []
  seasonIDs = []

  seasonIDsQS = await db.collection("/users/#{user.id}/seasons").get()

  seasons = await all(map(seasonIDsQS.docs, (doc) ->
    [ seasonDS, rolesDS ] = await all([
      db.collection('/seasons').doc(doc.id).get()
      db.collection("/seasons/#{doc.id}/users").doc(user.id).get()
    ])
    season = fbaHelpers.deserialize(seasonDS.data())

    leagueIDs = union(leagueIDs, [ "#{season.rel.league}" ])

    roles = if rolesDS.exists then (rolesDS.data()['access-control'] ? []) else []
    return merge(season, {
      val:
        roles: roles
        isAdmin: !isEmpty(intersection(roles, ['admin']))
        isCaptain: !isEmpty(intersection(roles, ['captain']))
        isOwner: !isEmpty(intersection(roles, ['owner']))
        isPlayer: !isEmpty(intersection(roles, ['player']))
    })
  ))

  leagues = await all(map(leagueIDs, (id) ->
    _ds = await db.collection('/leagues').doc(id).get()
    return { name: _ds.data().name, '-id': _ds.id }
  ))

  seasons = filter(seasons, (obj) -> DateTime.fromISO(obj.meta.created_at) > DateTime.fromISO('2021-01-01'))

  seasons = map(seasons, (_season) ->
    _season.league = find(leagues, { '-id': _season.rel.league })
    return _season
  )

  console.log seasons

  ctx.ok({ seasons })
  return
