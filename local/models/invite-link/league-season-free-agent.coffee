fbaInit      = require('@/local/lib/fba-init')
fbaHelpers   = require('@/local/lib/fba-helpers')
rand         = require('@/local/lib/rand')
{ DateTime } = require('luxon')


create = ({ league_id, season_id }) ->
  fba = await fbaInit()
  db = fba.firestore()

  now = DateTime.local().setZone('utc')
  _dt = now.toFormat('yyyyooo')
  _r = await rand.base62(32)

  code = "invite-link-#{_r}-#{parseInt(_dt).toString(36)}"

  invite_link =
    meta:
      created_at: now.toISO()
      deleted: false
      id: code
      updated_at: now.toISO()
      v: 1
      type: 'invite-link-league-season-free-agent'
    rel:
      league: league_id
      season: season_id
    val:
      code: code

  invite_link_s = fbaHelpers.serialize(invite_link)

  await db.collection('/invite-links').doc(invite_link.meta.id).set(invite_link_s, { merge: true })

  return invite_link


get = (id) ->
  illsfa = await fbaHelpers.retrieve('/invite-links', id)
  if illsfa
    return fbaHelpers.deserialize(illsfa)
  else
    null


getBySeason = (id) ->
  fba = await fbaInit()
  db = fba.firestore()

  QS = await db
    .collection('/invite-links')
    .where('rel-season', '==', id)
    .where('meta-type', '==', 'invite-link-league-season-free-agent')
    .get()

  if !QS.empty && QS.docs.length == 1
    return fbaHelpers.deserialize(QS.docs[0].data())
  else
    return null


module.exports = {
  create
  get
  getBySeason
}