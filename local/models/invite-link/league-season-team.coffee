fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
rand         = require('@stablelib/random')
{ DateTime } = require('luxon')

_create = ({ league_id, season_id }) ->
  fba = await fbaInit()
  db  = fba.firestore()

  now = DateTime.local().setZone('utc')

  id = "invite-link-#{rand.randomString(32)}"

  invite_link =
    meta:
      created_at: now.toISO()
      deleted: false
      id: id
      updated_at: now.toISO()
      v: 1
      type: 'invite-link-league-season-team'
    rel:
      league: league_id
      season: season_id
    val:
      code: id
      expires: null
      max_uses: null
      uses: 0

  invite_link_raw = fbaHelpers.serialize(invite_link)

  _wb = db.batch()
  _wb.set(db.collection('/invite-links').doc(invite_link.meta.id), invite_link_raw, { merge: true })
  await _wb.commit()

  return invite_link


_get = (id) ->
  invite_link = await fbaHelpers.get('/invite-links', id)
  return invite_link

_getBySeason = (id) ->
  fba = await fbaInit()
  db  = fba.firestore()

  QS = await db
    .collection('/invite-links')
    .where('rel-season', '==', id)
    .where('meta-type', '==', 'invite-link-league-season-team')
    .get()

  if !QS.empty && QS.docs.length == 1
    return fbaHelpers.deserialize(QS.docs[0].data())
  else
    return null

module.exports = {
  create: _create
  get: _get
  getBySeason: _getBySeason
}