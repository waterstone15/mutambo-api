Account      = require '@/local/models/account'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
flame        = require '@/local/lib/flame'
get          = require 'lodash/get'
intersection = require 'lodash/intersection'
isArray      = require 'lodash/isArray'
isObject     = require 'lodash/isObject'
kebabCase    = require 'lodash/kebabCase'
keys         = require 'lodash/keys'
map          = require 'lodash/map'
omitBy       = require 'lodash/omitBy'
pick         = require 'lodash/pick'
SeasonToUser = require '@/local/models/season-to-user'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (->


  _get = (id, options) ->
    defaults = {}
    defaults.values = [
      'meta-created-at'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-accounts'
      'val-address'
      'val-address-history'
      'val-birthday'
      'val-birthday-history'
      'val-display-name'
      'val-display-name-history'
      'val-email'
      'val-emails'
      'val-full-name'
      'val-full-name-history'
      'val-gender'
      'val-gender-history'
      'val-phone'
    ]

    values   = options?.values
    if isArray(values)
      values = intersection(defaults.values, values)
    else if isObject(values)
      meta   = map(values.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(values.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(values.val,  (v) -> "val-#{kebabCase(v)}")
      values = intersection(defaults.values, union(val, meta))
    else
      values = defaults.values

    user = await fbaH.get('/users', id, { fields: values })
    return user


  _getByUid = (uid, options) ->
    account = await Account.get(uid) ? await Account.create(uid)
    user = { meta: { id: account.rel.user } }

    values = options?.values
    if values != []
      user = await this.get(user.meta.id, { values })

    return user


  _update = (id, obj) ->

    now = DateTime.local().setZone('utc')

    [ fba, user ] = await all([ fbaI(), _get(id) ])
    db = fba.firestore()

    allowed_val  = [ 'address', 'birthday', 'gender', 'display_name', 'full_name', 'phone' ]

    updates =
      meta: {
        updated_at: now.toISO()
      }
      val: {
        ...(pick(obj.val, allowed_val))
        ...(if get(obj, 'val.address') then { address_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), address: obj.val.address }) })
        ...(if get(obj, 'val.birthday') then { birthday_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), birthday: obj.val.birthday }) })
        ...(if get(obj, 'val.display_name') then { display_name_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), display_name: obj.val.display_name }) })
        ...(if get(obj, 'val.full_name') then { full_name_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), full_name: obj.val.full_name }) })
        ...(if get(obj, 'val.gender') then { gender_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), gender: obj.val.gender }) })
        ...(if get(obj, 'val.phone') then { phone_history: fba.firestore.FieldValue.arrayUnion({ created_at: now.toISO(), phone: obj.val.phone }) })
      }

    if  updates.val.display_name || updates.val.full_name
      await SeasonToUser.updateAll({ user, obj: updates })

    updates_s = fbaH.serialize(updates) ? {}
    await db.collection('/users').doc(id).update(updates_s)

    return



  # ---------------------------------------------------------------------------

  return {
    get: _get
    getByUid: _getByUid
    update: _update
  }

)()
