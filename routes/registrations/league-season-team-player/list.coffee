fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
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

  # { uid } = ctx.state.fbUser

  # [ fba, user ] = await all([
  #   fbaInit()
  #   User.getByUid(uid, { values: meta: ['id'] })
  # ])

  # db = fba.firestore()

  # leagueIDs = []
  # teamIDs = []
  # seasonIDs = []
  # ltrsIDs = []

  # rsQ = db
  #   .collection('/registrations')
  #   .orderBy('-created-at', 'desc')
  #   .where('-deleted', '==', false)
  #   .where('-v', '==', 2)
  #   .where('user', '==', user.meta.id)
  #   .limit(10000)

  # rsQS = await rsQ.get()

  # rsDSs = if !rsQS.empty then rsQS.docs else []
  # registrations = map(rsDSs, (rDS) ->
  #   leagueIDs = union(leagueIDs, ["#{rDS.data().league}"])
  #   seasonIDs = union(seasonIDs, ["#{rDS.data().season}"])
  #   teamIDs = union(teamIDs, ["#{rDS.data().team}"])
  #   ltrsIDs = union(ltrsIDs, ["#{rDS.data().ltrs}"])

  #   return merge(rDS.data(), { '-created-at': DateTime.fromSeconds(rDS.createTime._seconds).toUTC().toISO() })
  # )

  # leaguesP = all(map(leagueIDs, (id) ->
  #   _ds = await db.collection('/leagues').doc(id).get()
  #   _l = fbaHelpers.deserialize(_ds.data())
  #   return { name: _l.val.name, '-id': _l.meta.id }
  # ))
  # seasonsP = all(map(seasonIDs, (id) ->
  #   _ds = await db.collection('/seasons').doc(id).get()
  #   _s = fbaHelpers.deserialize(_ds.data())
  #   return { name: _s.val.name, '-id': _s.meta.id }
  # ))
  # teamsP = all(map(teamIDs, (id) ->
  #   _ds = await db.collection('/teams').doc(id).get()
  #   return { name: _ds.data().name, '-id': _ds.id }
  # ))
  # ltrssP = all(map(ltrsIDs, (id) ->
  #   id = "registration-settings-#{id}" if /ltrs/.test(id) && !/registration-settings/.test(id)
  #   _ds = await db.collection('/registration-settings').doc(id).get()
  #   return { 'price-formatted': _ds.data()['val-price-formatted'], '-id': _ds.data()['meta-id'] }

  # ))
  # { leagues, seasons, teams, ltrss } = await hash({
  #   leagues: leaguesP
  #   seasons: seasonsP
  #   teams: teamsP
  #   ltrss: ltrssP
  # })

  # registrations = map(registrations, (r) ->
  #   r.league = find(leagues, { '-id': r.league })
  #   r.season = find(seasons, { '-id': r.season })
  #   r.team = find(teams, { '-id': r.team })
  #   ltrsid = if /ltrs/.test(r.ltrs) && !/registration-settings/.test(r.ltrs) then "registration-settings-#{r.ltrs}" else r.ltrs
  #   r.ltrs = find(ltrss, { '-id': ltrsid })
  #   return r
  # )

  # _2021 = DateTime.fromISO('2021-01-01')
  # registrations = filter(registrations, (_r) -> DateTime.fromISO(_r['-created-at']) > _2021)
  # registrations = filter(registrations, (_r) -> _r['stripe-payment-status'] == 'paid')

  # ctx.ok({ registrations })
  ctx.ok({ })
  return
