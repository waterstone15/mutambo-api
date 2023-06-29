Account      = require('@/local/models/account')
fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
intersection = require('lodash/intersection')
isArray      = require('lodash/isArray')
isEmpty      = require('lodash/isEmpty')
isObject     = require('lodash/isObject')
kebabCase    = require('lodash/kebabCase')
map          = require('lodash/map')
merge        = require('lodash/merge')
rand         = require('@stablelib/random')
union        = require('lodash/union')
User         = require('@/local/models/user')
Vault        = require('@/local/lib/arctic-vault')
stripeI      = require('stripe')
{ all }      = require('rsvp')
{ hash }     = require('rsvp')
{ DateTime } = require('luxon')

module.exports = (->


  _create = (obj) ->
    vault = await Vault.open()

    stripe = stripeI(vault.secrets.kv.STRIPE_SECRET_KEY)

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    year_day = DateTime.local().setZone('utc').toFormat('yyyyooo')
    random = await rand.randomString(32)

    if obj.meta.type == 'payment-registration-team-per-season'
      { league, price, season, } = await hash({
        league: fbaH.get('/leagues', obj.rel.league)
        price:  fbaH.get('/prices', obj.rel.price)
        season: fbaH.get('/seasons', obj.rel.season)
      })

      stripe_price = await stripe.prices.retrieve(price.ext.stripe_price)
      total        = stripe_price.unit_amount / 100
      itemized     = [{ name: 'Team Registration', amount: total }]
      currency     = stripe_price.currency

    payment = merge({
      ext:
        stripe_price: if stripe_price then stripe_price.id else null
      meta:
        created_at: now.toISO()
        deleted: false
        id: "payment-#{db.collection('/payments').doc().id}"
        type: 'payment'
        updated_at: now.toISO()
        v: 2
      rel:
        league: null
        payee: null
        payee_type: null
        payer: null
        payer: null
        price: null
        registration: null
        season: null
        team: null
      val:
        code: "#{random}#{parseInt(year_day).toString(36)}"
        description: "Payment to #{league.val.name}, #{season.val.name} for team registration."
        payment_currency: currency ? null
        payment_itemized: itemized ? null
        payment_total: total ? null
        status: 'unpaid' # 'paid'
    }, obj)


    await db.collection('/payments').doc(payment.meta.id).set(fbaH.serialize(payment))

    return payment


  _get = (id, options = {}) ->
    fba = await fbaI()
    db  = fba.firestore()

    defaults = {}
    defaults.values = [
      'ext-stripe-sku'
      'meta-created-at'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-game'
      'rel-league'
      'rel-offender'
      'rel-payee'
      'rel-payee-type'
      'rel-payer'
      'rel-registration'
      'rel-season'
      'rel-team'
      'val-code'
      'val-description'
      'val-payment-currency'
      'val-payment-itemized'
      'val-payment-total'
      'val-status'
    ]

    values = defaults.values
    if isObject(options.values)
      ext    = map(values.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(values.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(values.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(values.val,  (v) -> "val-#{kebabCase(v)}")
      values = intersection(defaults.values, union(val, meta))
    else
      values = defaults.values

    payment = await fbaH.get('/payments', id, { fields: values })

    return payment



  # ---------------------------------------------------------------------------

  return {
    get: _get
    create: _create
  }

)()
