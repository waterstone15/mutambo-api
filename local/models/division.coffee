Account      = require('@/local/models/account')
fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
get          = require('lodash/get')
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


  _create = ({ data, league, season }) ->

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    division = merge({
      meta:
        created_at: now.toISO()
        deleted: false
        id: "division-#{db.collection('/divisions').doc().id}"
        type: 'division-league-season'
        updated_at: now.toISO()
        v: 2
      rel:
        league: get(league, 'meta.id') ? null
        season: get(season, 'meta.id') ? null
      val:
        description: data.description ? null
        icon: data.icon ? null
        name: data.name ? ''
    })


    division_s = fbaH.serialize(division)

    _wb = db.batch()
    _wb.set(db.collection("/divisions").doc(division.meta.id), division_s, { merge: true })
    await _wb.commit()


    return division


  _get = (id, options = {}) ->
    fba = await fbaI()
    db  = fba.firestore()

    defaults = {}
    defaults.values = [
      'meta-created-at'
      'meta-created-by'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-league'
      'rel-season'
      'val-description'
      'val-icon'
      'val-name'
    ]

    values = defaults.values
    if isObject(options.values)
      ext    = map(values.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(values.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(values.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(values.val,  (v) -> "val-#{kebabCase(v)}")
      values = intersection(defaults.values, union(ext, meta, rel, val))
    else
      values = defaults.values

    division = await fbaH.get('/divisions', id, { fields: values })

    return division



  # ---------------------------------------------------------------------------

  return {
    create: _create
    get:    _get
  }

)()
