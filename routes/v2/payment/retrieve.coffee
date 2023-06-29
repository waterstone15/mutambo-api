FLI        = require '@/local/lib/flame-lib-init'
idempotent = require '@/local/lib/idempotent'
LModel     = require '@/local/models/flame-lib/league'
log        = require '@/local/lib/log'
merge      = require 'lodash/merge'
money      = require 'currency.js'
PaModel    = require '@/local/models/flame-lib/payment'
PrModel    = require '@/local/models/flame-lib/price'
stripeI    = require 'stripe'
User       = require '@/local/models/user'
Vault      = require '@/local/lib/arctic-vault'
{ all }    = require 'rsvp'

module.exports = (ctx) ->

  vault  = await Vault.open()
  stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)

  { uid } = ctx.state.fbUser
  { code } = ctx.request.body

  if !uid
    ctx.unauthorized({})
    return

  Flame   = await FLI('main')
  
  League  = await LModel()
  Payment = await PaModel()
  Price   = await PrModel()

  pQ = [[ 'where', 'val.code', '==', code ]]
  payment = await Payment.find(pQ).read()

  if !(/[0-9]{5}\.[0-9]{5}\.[0-9]{5}/.test(payment.meta.v))
    payment = merge(payment, {
      val:
        currency: payment.val.payment_currency
        items:    payment.val.payment_itemized
        total:    payment.val.payment_total
    })

  if !payment
    ctx.badRequest({})

  league = await League.get(payment.rel.league).read()

  pr_query = [
    [ 'where', 'val.amount', '==', payment.val.total ]
    [ 'where', 'val.currency', '==', payment.val.currency ]
    [ 'where', 'ext.stripe_product', '==', league.ext.stripe_product ]
  ]
  price = await Price.find(pr_query).read()
  
  if !price
    obj =
      currency: payment.val.currency
      product: league.ext.stripe_product
      unit_amount: money(payment.val.total).intValue
    
    ik = idempotent.key({ seed: "#{league.ext.stripe_product}-#{payment.val.currency}-#{payment.val.total}" })
    stripe_price = await stripe.prices.create(obj, { idempotencyKey: ik })

    price = Price.create({
      ext:
        stripe_price:   stripe_price.id
        stripe_product: league.ext.stripe_product
      val:
        amount:         payment.val.total
        currency:       payment.val.currency
    })

    if !price.ok()
      ctx.badRequest({})
      return

    await price.save().write()
    price = price.obj()


  if !payment.ext.stripe_price
    payment = Payment.create(merge(payment, {
      ext:
        stripe_price: price.ext.stripe_price
        stripe_product: league.ext.stripe_product
      rel:
        price: price.meta.id
    }))
    payment_paths = [ 'ext.stripe_price', 'ext.stripe_product', 'rel.price' ]

    if !payment.ok()
      ctx.badRequest({})
      return   

    await payment.update(payment_paths).write()
    payment = payment.obj()


  ctx.ok({ payment })
  return