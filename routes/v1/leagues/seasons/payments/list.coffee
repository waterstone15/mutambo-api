capitalize   = require 'lodash/capitalize'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
money        = require 'currency.js'
Payment      = require '@/local/models/flame/payment'
Payment      = require '@/local/models/flame/payment'
pick         = require 'lodash/pick'
Price        = require '@/local/models/flame/price'
Product      = require '@/local/models/flame/product'
rand         = require '@stablelib/random'
SeasonToUser = require '@/local/models/season-to-user'
stripeI      = require 'stripe'
User         = require '@/local/models/user'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id } = ctx.request.body

  fba = await fbaI()
  db = fba.firestore()

  user = await User.getByUid(uid)
  authorized = await SeasonToUser.anyRole({ season: { meta: { id: season_id }}, user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()

  page = await Payment.list([
    [ 'where', 'meta-type', '==', 'payment' ]
    [ 'where', 'rel-season', '==', season_id ]
  ])
  page.page_items = map(page.page_items, (p) ->
    return merge(p, {
      val:
        title: p.val.payment_itemized[0].name
      ui:
        amount_formatted: money(p.val.payment_itemized[0].amount).format()
        status_formatted: capitalize(p.val.status)
    })
  )

  ctx.ok({ page })
  return
