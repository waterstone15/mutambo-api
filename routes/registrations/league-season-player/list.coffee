# fbaHelpers   = require('@/local/lib/fba-helpers')
# fbaInit      = require('@/local/lib/fba-init')
# filter       = require('lodash/filter')
# find         = require('lodash/find')
# map          = require('lodash/map')
# merge        = require('lodash/merge')
# pick         = require('lodash/pick')
# sortBy       = require('lodash/sortBy')
# union        = require('lodash/union')
# unionBy      = require('lodash/unionBy')
# User         = require('@/local/models/user')
# { all }      = require('rsvp')
# { DateTime } = require('luxon')
# { hash }     = require('rsvp')


# module.exports = (ctx) ->

#   { uid } = ctx.state.fbUser

#   [ fba, user ] = await all([
#     fbaInit()
#     User.getByUid(uid, { values: meta: ['id'] })
#   ])

#   db = fba.firestore()

#   leagueIDs = []
#   teamIDs = []
#   seasonIDs = []
#   registration_settingsIDs = []

#   rsQ = db
#     .collection('/registrations')
#     .orderBy('meta-created-at', 'desc')
#     .where('meta-deleted', '==', false)
#     .where('meta-v', '==', 3)
#     .where('rel-user', '==', user.meta.id)
#     .where('meta-type', '==', 'registration-league-season-player')
#     .limit(10000)

#   rsQS = await rsQ.get()

#   rsDSs = if !rsQS.empty then rsQS.docs else []
#   registrations = map(rsDSs, (rDS) ->
#     _r = fbaHelpers.deserialize(rDS.data())
#     leagueIDs = union(leagueIDs, ["#{_r.rel.league}"])
#     seasonIDs = union(seasonIDs, ["#{_r.rel.season}"])
#     teamIDs = union(teamIDs, ["#{_r.rel.team}"])
#     registration_settingsIDs = union(registration_settingsIDs, ["#{_r.rel.registration_settings}"])

#     return _r
#   )

#   leaguesP = all(map(leagueIDs, (id) ->
#     _ds = await db.collection('/leagues').doc(id).get()
#     _l = fbaHelpers.deserialize(_ds.data())
#     return { name: _l.val.name, id: _l.meta.id }
#   ))
#   seasonsP = all(map(seasonIDs, (id) ->
#     _ds = await db.collection('/seasons').doc(id).get()
#     _s = fbaHelpers.deserialize(_ds.data())
#     return { name: _s.val.name, id: _s.meta.id }
#   ))
#   teamsP = all(map(teamIDs, (id) ->
#     _ds = await db.collection('/teams').doc(id).get()
#     return { name: _ds.data().name, id: _ds.id }
#   ))
#   registration_settingsP = all(map(registration_settingsIDs, (id) ->
#     _ds = await db.collection('/registration-settings').doc(id).get()
#     return fbaHelpers.deserialize(_ds.data())
#   ))
#   { leagues, seasons, teams, registration_settingses } = await hash({
#     leagues: leaguesP
#     seasons: seasonsP
#     teams: teamsP
#     registration_settingses: registration_settingsP
#   })

#   registrations = map(registrations, (_r) ->
#     _r.val.league = find(leagues, { id: _r.rel.league })
#     _r.val.season = find(seasons, { id: _r.rel.season })
#     _r.val.team = find(teams, { id: _r.rel.team })
#     _r.val.registration_settings = find(registration_settingses, { meta: { id: _r.rel.registration_settings } })
#     return _r
#   )

#   ctx.ok({ registrations })
#   return
