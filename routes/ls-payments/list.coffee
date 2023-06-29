convert      = require('@/local/lib/convert')
difference   = require('lodash/difference')
fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
includes     = require('lodash/includes')
intersection = require('lodash/intersection')
isEmpty      = require('lodash/isEmpty')
isObject     = require('lodash/isObject')
map          = require('lodash/map')
merge        = require('lodash/merge')
omit         = require('lodash/omit')
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
  { season_id } = ctx.query

  [ fba, user ] = await all([
    fbaInit(),
    User.getByUid(uid, { values: [] })
  ])
  db = fba.firestore()

  # cache_id = await convert.toHashedBase32("#{season_id}-payments-admin")

  league = {}
  payments = []
  season = {}

  # [ accessDS, cacheDS, seasonDS ] = await all([
  #   db.collection("/seasons/#{season_id}/users").doc(user.id).get()
  #   db.collection('/request-caches').doc(cache_id).get()
  #   db.collection('/seasons').doc(season_id).get()
  # ])

  [ accessDS, seasonDS ] = await all([
    db.collection("/seasons/#{season_id}/users").doc(user.id).get()
    db.collection('/seasons').doc(season_id).get()
  ])

  if !seasonDS.exists
    ctx.badRequest()
    return

  if !includes(accessDS.data()['access-control'], 'admin')
    ctx.unauthorized()
    return

  # if cacheDS.exists && cacheDS.data().valid == true
  #   { league, people, season } = JSON.parse(cacheDS.data().data)
  #   ctx.ok({ league, people, season })
  #   return

  season = pick(fbaHelpers.deserialize(seasonDS.data()), [ 'meta.id', 'val.name', 'rel.league' ])

  leagueDS = await db.collection('/leagues').doc(season.rel.league).get()

  if !leagueDS.exists
    ctx.badRequest()
    return

  league = pick(fbaHelpers.deserialize(leagueDS.data()), [ 'meta.id', 'val.logo_url', 'val.name', ])

  paymentsQS = await db.collection('/payments').where('rel-season', '==', season_id).get()
  payments = await all(map(paymentsQS.docs ? [], (paymentDS) ->
    payment = omit(
      fbaHelpers.deserialize(paymentDS.data()),
      [ 'ext.stripe_checkout_session', 'ext.stripe_squ', 'val.code' ]
    )
    return payment
  ))
  payments = filter(payments, isObject)

  # await db.collection('/request-caches').doc(cache_id).set({
  #   valid: true
  #   data: JSON.stringify({ league, people, season })
  # })

  ctx.ok({ league, payments, season })
  return
