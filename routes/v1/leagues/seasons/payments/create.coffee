fbaI         = require '@/local/lib/fba-init'
fbaH         = require '@/local/lib/fba-helpers'
money        = require 'currency.js'
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
  { currency, description, price, season, title } = ctx.request.body

  fba = await fbaI()
  db = fba.firestore()

  user = await User.getByUid(uid)
  season = pick(season, [ 'meta.id', 'rel.league' ])
  authorized = await SeasonToUser.anyRole({ season, user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()
    return

  vault = await Vault.open()
  stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)
  # stripe = stripeI(process.env.STRIPE_SECRET_KEY_OVERRIDE)


  # 1. Use selected product, or default to general product
  product = '<product_id>'

  # 2. Check if existing price matches total, if yes use that price, otherwise create a price
  p = await Price.find([[ 'where', 'val-price', '==', price ]])
  if p == null
    console.log 'create new price'
    s_price = await stripe.prices.create({
      unit_amount: money(price).intValue
      currency: 'usd'
      product: product
    })
    p = Price.create({
      ext:
        stripe_price: s_price.id
      val:
        currency: 'usd'
        price: money(price, { pattern: '#' }).format()
      rel:
        product: '<product_id>'
    })
    await p.save()
    p = p.obj()

  # 3. Crete new payment
  now = DateTime.local().setZone('utc')
  payment =
    ext:
      stripe_checkout_session: null
      stripe_price: p.ext.stripe_price
    meta:
      collection: 'payments'
      created_at: now.toISO()
      deleted: false
      id: "payment-#{rand.randomString(32)}"
      type: 'payment'
      updated_at: now.toISO()
      v: 1
    rel:
      league: season.rel.league
      payee: season.rel.league
      payer: null
      season: season.meta.id
    val:
      code: rand.randomString(32)
      description: description
      payee_type: 'league'
      payment_itemized: [{ amount: (money(price).intValue / 100), name: title }]
      status: 'unpaid'
      payment_total: (money(price).intValue / 100)



  await db
    .collection('/payments')
    .doc(payment.meta.id)
    .set(fbaH.serialize(payment))



  ctx.ok({})
  return
