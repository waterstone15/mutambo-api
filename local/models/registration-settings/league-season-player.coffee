fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
keys         = require('lodash/keys')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
{ DateTime } = require('luxon')


create = ({ league_id, season_id, val_overrides }) ->
  val_overrides = val_overrides ? {}
  fba = await fbaInit()
  db = fba.firestore()

  now = DateTime.local().setZone('utc')

  registration_settings =
    meta:
      created_at: now.toISO()
      deleted: false
      id: "registration-settings-#{db.collection('/id').doc().id}"
      type: 'registration-settings-league-season-player'
      updated_at: now.toISO()
      v: 1
    rel:
      league: league_id
      season: season_id
    val:
      player_address_required: true
      player_birthday_required: true
      player_display_name_required: true
      player_full_name_required: true
      open: true
      price: 0
      price_formatted: '$0.00'
      img_url: ''
      stripe_sku: ''
  registration_settings.val = merge(registration_settings.val, pick(val_overrides, keys(registration_settings.val)))

  registration_settings_s = fbaHelpers.serialize(registration_settings)

  await db.collection('/registration-settings').doc(registration_settings.meta.id).set(registration_settings_s, { merge: true })

  return registration_settings


get = (id) ->
  registration_settings_raw = await fbaHelpers.retrieve('/registration-settings', id)
  if registration_settings_raw
    return fbaHelpers.deserialize(registration_settings_raw)
  else
    null

getByLeagueSeason = ({ league_id, season_id }) ->
  fba = await fbaInit()
  db = fba.firestore()

  QS = await db
    .collection('/registration-settings')
    .where('rel-league', '==', league_id)
    .where('rel-season', '==', season_id)
    .get()

  if !QS.empty && QS.docs.length == 1
    return fbaHelpers.deserialize(QS.docs[0].data())
  else
    return null


module.exports = {
  create
  get
  getByLeagueSeason
}

