fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
rand         = require('@stablelib/random')
{ DateTime } = require('luxon')


_create = ({ league_id, season_id, team_id }) ->
  fba = await fbaI()
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
      type: 'invite-link-league-season-team-manager'
    rel:
      league: league_id
      season: season_id
      team:   team_id
    val:
      code: id
      expires: null
      max_uses: null
      uses: 0

  invite_link_raw = fbaH.serialize(invite_link)

  _wb = db.batch()
  _wb.set(db.collection('/invite-links').doc(invite_link.meta.id), invite_link_raw, { merge: true })
  await _wb.commit()

  return invite_link


_get = (id) ->
  invite_link = await fbaH.get('/invite-links', id)
  return invite_link


_getByTeam = (team_id) ->
  filters = [
    [ 'rel-team', '==', team_id ]
    [ 'meta-type', '==', 'invite-link-league-season-team-manager' ]
  ]
  invite_link = await fbaH.find('/invite-links', filters)
  return invite_link


module.exports = {
  create:    _create
  get:       _get
  getByTeam: _getByTeam
}