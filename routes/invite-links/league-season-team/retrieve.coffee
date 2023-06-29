fbaHelpers = require('@/local/lib/fba-helpers')
fbaInit    = require('@/local/lib/fba-init')
ILLST      = require('@/local/models/invite-link/league-season-team')
pick       = require('lodash/pick')
{ all }    = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  if !uid
    ctx.unauthorized()
    return

  invite_link = await ILLST.get(id)

  if !invite_link
    ctx.badRequest()
    return

  fba = await fbaInit()
  db = fba.firestore()

  [ lDS, sDS, tDS ] = await all([
    db.collection('/leagues').doc(invite_link.rel.league).get()
    db.collection('/seasons').doc(invite_link.rel.season).get()
  ])

  league = pick(fbaHelpers.deserialize(lDS.data()), ['val.name'])
  season = pick(fbaHelpers.deserialize(sDS.data()), ['val.name', 'val.settings.team_registration_status'])

  invite_link.val.league = league
  invite_link.val.season = season

  ctx.ok({ invite_link })
