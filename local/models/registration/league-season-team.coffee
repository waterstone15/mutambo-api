fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
keys         = require('lodash/keys')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
{ DateTime } = require('luxon')


create = ({ league_id, season_id, team_id, registration_settings_id, val_overrides }) ->
  val_overrides = val_overrides ? {}
  fba = await fbaInit()
  db = fba.firestore()

  now = DateTime.local().setZone('utc')

  registration =
    meta:
      created_at: now.toISO()
      deleted: false
      id: "registration-#{db.collection('/id').doc().id}"
      type: 'registration-league-season-team'
      updated_at: now.toISO()
      v: 3
    rel:
      league: league_id
      registration_settings: registration_settings_id
      season: season_id
      team: team_id
      user: user_id
    val:
      notes: ''
      user_snapshoc: {}
      stripe_checkout_session: ''
      stripe_payment_status: ''
  registration.val = merge(registration.val, pick(val_overrides, keys(registration.val)))

  registration_s = fbaHelpers.serialize(registration)

  await db.collection('/registrations').doc(registration.meta.id).set(registration_s, { merge: true })

  return registration


get = (id) ->
  registration_raw = await fbaHelpers.retrieve('/registrations', id)
  if registration_raw
    return fbaHelpers.deserialize(registration_raw)
  else
    null


module.exports = {
  create
  get
}