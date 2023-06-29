fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
map          = require('lodash/map')
merge        = require('lodash/merge')
omit         = require('lodash/omit')
pick         = require('lodash/pick')
sortBy       = require('lodash/sortBy')
stripeI      = require('stripe')
union        = require('lodash/union')
unionBy      = require('lodash/unionBy')
User         = require('@/local/models/user')
Vault        = require('@/local/lib/arctic-vault')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')


module.exports = (ctx) ->
  vault = await Vault.open()

  stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])

  db = fba.firestore()

  rsQ = db
    .collection('/registrations')
    .orderBy('meta-created-at', 'desc')
    .where('meta-v', '==', 4)
    .where('meta-deleted', '==', false)
    .where('rel-user', '==', user.meta.id)
    .limit(1000)
  rsQS = await rsQ.get()
  rsDSs = if !rsQS.empty then rsQS.docs else []

  registrations = await all(map(rsDSs, (rDS) ->
    r = fbaH.deserialize(rDS.data())

    [ league, payment, season, team, ] = await all([
      if r.rel.league  then fbaH.get('/leagues', r.rel.league) else {}
      if r.rel.payment then fbaH.get('/payments', r.rel.payment) else {}
      if r.rel.season  then fbaH.get('/seasons', r.rel.season) else {}
      if r.rel.team    then fbaH.get('/teams', r.rel.team) else {}
    ])
    season = omit(season, ['val.settings'])

    r = merge(r, { val: { league,  season,  payment, team }})
    return r
  ))

  ctx.ok({ registrations })
  return



