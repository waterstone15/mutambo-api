fbaHelpers     = require('@/local/lib/fba-helpers')
fbaInit        = require('@/local/lib/fba-init')
InviteLinkLSFA = require('@/local/models/invite-link/league-season-free-agent')
pick           = require('lodash/pick')
{ all }        = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  if !uid
    ctx.unauthorized()
    return

  invite_link = await InviteLinkLSFA.get(id)

  if !invite_link
    ctx.badRequest()
    return

  fba = await fbaInit()
  db = fba.firestore()

  [ lDS, sDS ] = await all([
    db.collection('/leagues').doc(invite_link.rel.league).get()
    db.collection('/seasons').doc(invite_link.rel.season).get()
  ])

  league = pick(fbaHelpers.deserialize(lDS.data()), [ 'val.name', 'val.sport' ])
  season = pick(fbaHelpers.deserialize(sDS.data()), [ 'val.name', ])

  ctx.ok({ invite_link, league, season })
