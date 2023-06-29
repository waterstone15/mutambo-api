fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
filter       = require('lodash/filter')
find         = require('lodash/find')
includes     = require('lodash/includes')
map          = require('lodash/map')
merge        = require('lodash/merge')
omit         = require('lodash/omit')
pick         = require('lodash/pick')
reverse      = require('lodash/reverse')
stripeI      = require('stripe')
truncate     = require('lodash/truncate')
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
  { season_id } = ctx.request.query

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

  rIDsQS = await db.collection("/seasons/#{season.meta.id}/registrations").get()
  rIDs   = filter(map((rIDsQS.docs ? []), (rDS) -> if ('2022' > DateTime.fromSeconds(rDS.createTime.seconds).toISO()) then null else rDS.id))

  registrations = await all(map((rIDs), (id) ->
    rDS = await db.collection('/registrations').doc(id).get()
    if (rDS.data()['meta-v'] != 4)
      return null

    r = fbaH.deserialize(rDS.data())
    [ payment, team, user ] = await all([
      if r.rel.payment then fbaH.get('/payments', r.rel.payment) else {}
      if r.rel.team    then fbaH.get('/teams', r.rel.team)       else {}
      if r.rel.user    then fbaH.get('/users', r.rel.user)       else {}
    ])
    user = pick(user, [ 'val.full_name', 'val.email', 'meta.id' ])

    r = merge(r, { val: { payment, team, user }})
    return r
  ))
  registrations = filter(registrations)
  registrations = filter(registrations, (r) -> r.meta.type == 'league-season-team')
  registrations = filter(registrations, (r) -> r.meta.created_by != 'Cj6nbEFWyXQm4NL2W9T9HSZRH242')
  ctx.ok({ registrations })
  return



