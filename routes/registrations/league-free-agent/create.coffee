convert         = require('@/local/lib/convert')
fbaHelpers      = require('@/local/lib/fba-helpers')
fbaInit         = require('@/local/lib/fba-init')
isEmpty         = require('lodash/isEmpty')
isNumber        = require('lodash/isNumber')
map             = require('lodash/map')
merge           = require('lodash/merge')
ok              = require('@/local/lib/ok')
padStart        = require('lodash/padStart')
rand            = require('@/local/lib/rand')
RegistrationLSP = require('@/local/models/registration/league-season-player')
User            = require('@/local/models/user')
{ all }         = require('rsvp')
{ DateTime }    = require('luxon')

module.exports = (ctx) ->

  now = DateTime.local().setZone('utc')

  { uid } = ctx.state.fbUser
  { invite_link, player_card } = ctx.request.body

  if !uid
    ctx.unauthorized()
    return

  if isEmpty(player_card.val.about)
    ctx.badRequest()
    return

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: { meta: [ 'id'], val: [ 'email' ] }})
  ])
  db = fba.firestore()

  [ ilDS, pcQS ] = await all([
    db.collection('/invite-links').doc(invite_link.meta.id).get()
    db.collection('/player-cards').where('rel-user', '==', user.meta.id).where('val-sport', '==', player_card.val.sport).get()
  ])

  if !ilDS.exists
    ctx.badRequest()
    return

  _dt = DateTime.local().setZone('utc').toFormat('yyyyooo')
  _r = await rand.base62(32)

  code = "#{_r}#{parseInt(_dt).toString(36)}"

  pc_base =
    meta:
      created_at: now.toISO()
      deleted: false
      id: "player-card-#{db.collection('/player-cards').doc().id}"
      type: 'player-card'
      updated_at: now.toISO()
      v: 1
    rel:
      user: user.meta.id
    val:
      about: ''
      code: code
      share_leagues: false
      share_protected: false
      share_public: false
      sport: ''

  pc_updated =
    meta:
      updated_at: now.toISO()
    val:
      share_leagues: true
      sport: player_card.val.sport
      about: player_card.val.about

  pc_final = merge({}, pc_base)
  pc_final = merge(pc_final, fbaHelpers.deserialize(pcQS.docs[0].data())) unless pcQS.empty
  pc_final = merge(pc_final, pc_updated)

  [ cache_id_1, cache_id_2, cache_id_3 ] = await all([
    convert.toHashedBase32("#{ilDS.data()['rel-league']}-free-agents")
    convert.toHashedBase32("#{ilDS.data()['rel-league']}-free-agents-captain")
    convert.toHashedBase32("#{ilDS.data()['rel-league']}-free-agents-admin")
  ])

  _wb = db.batch()
  _wb.set(db.collection('/users').doc(user.meta.id), {
    'val-display-name': player_card.val.name
  }, { merge: true })
  _wb.set(db.collection('/player-cards').doc(pc_final.meta.id), fbaHelpers.serialize(pc_final), { merge: true })
  _wb.set(db.collection("/player-cards/#{pc_final.meta.id}/rel-leagues").doc(ilDS.data()['rel-league']), {}, { merge: true })
  _wb.set(db.collection("/leagues/#{ilDS.data()['rel-league']}/rel-player-cards").doc(pc_final.meta.id), {}, { merge: true })
  _wb.set(db.collection('/request-caches').doc(cache_id_1), { valid: false }, { merge: true })
  _wb.set(db.collection('/request-caches').doc(cache_id_2), { valid: false }, { merge: true })
  _wb.set(db.collection('/request-caches').doc(cache_id_3), { valid: false }, { merge: true })
  await _wb.commit()

  ctx.ok({})
  return



