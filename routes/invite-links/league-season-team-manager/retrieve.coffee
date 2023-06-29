fbaH    = require('@/local/lib/fba-helpers')
fbaI    = require('@/local/lib/fba-init')
ILLSTM  = require('@/local/models/invite-link/league-season-team-manager')
pick    = require('lodash/pick')
{ all } = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id }  = ctx.params

  if !uid
    ctx.unauthorized()
    return

  invite_link = await ILLSTM.get(id)

  if !invite_link
    ctx.badRequest()
    return

  fba = await fbaI()
  db  = fba.firestore()

  [ league, season, team ] = await all([
    fbaH.get('/leagues', invite_link.rel.league)
    fbaH.get('/seasons', invite_link.rel.season)
    fbaH.get('/teams', invite_link.rel.team)
  ])
  league = pick(league, ['val.name'])
  season = pick(season, ['val.name', 'val.settings.manager_registration_status', 'val.settings.team_manager_limit'])
  team   = pick(team,   ['val.name', 'val.manager_count'])

  team.val.manager_count ?= 0

  invite_link.val.league = league
  invite_link.val.season = season
  invite_link.val.team   = team

  ctx.ok({ invite_link })
