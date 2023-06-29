fbaH           = require '@/local/lib/fba-helpers'
FLI            = require '@/local/lib/flame-lib-init'
hash           = require '@/local/lib/hash'
includes       = require 'lodash/includes'
InviteLinkLSFA = require '@/local/models/invite-link/league-season-free-agent'
InviteLinkLST  = require '@/local/models/invite-link/league-season-team'
merge          = require 'lodash/merge'
omit           = require 'lodash/omit'
pick           = require 'lodash/pick'
SModel         = require '@/local/models/flame-lib/season'
sortBy         = require 'lodash/sortBy'
U2SModel       = require '@/local/models/flame-lib/user-to-season'
User           = require '@/local/models/user'
{ all }        = require 'rsvp'
{ DateTime }   = require 'luxon'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { id } = ctx.params

  Flame = await FLI('main')
  db    = Flame.wildfire().firestore()
  
  Season = await SModel()
  UserToSeason = await U2SModel()

  season = await Season.get(id).read()
  if /[0-9]{5}.[0-9]{5}.[0-9]{5}/.test(season.meta.v)
    return require('@/routes/v2/season/retrieve')(ctx)
    

  user = await User.getByUid(uid)

  # [ seasonDS, rolesDS, LSFA_invite_link ] = await all([

  u2sQ = [
    [ 'where', 'rel.season', '==', id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ seasonDS, rolesDS, user_to_season ] = await all([
    db.collection('/seasons').doc(id).get()
    db.collection("/seasons/#{id}/users").doc(user.meta.id).get()
    UserToSeason.find(u2sQ).read()
    # InviteLinkLSFA.getBySeason(id)
    # InviteLinkLST.getBySeason(id)
  ])

  if !seasonDS.exists && !season
    ctx.badRequest()
    return

  if !user_to_season
    season = fbaH.deserialize(seasonDS.data())

  if !!user_to_season
    roles = sortBy(user_to_season.val.roles)
  else 
    roles = sortBy(rolesDS.data?()?['access-control'] ? [])

  season = merge(season, {
    val:
      isAdmin:   includes(roles, 'admin')
      isCaptain: includes(roles, 'captain')
      isManager: includes(roles, 'manager')
      isPlayer:  includes(roles, 'player')
      roles:     roles
  })

  # if !LSFA_invite_link
  #   LSFA_invite_link = await InviteLinkLSFA.create({
  #     season_id: season.meta.id
  #     league_id: season.rel.league
  #   })

  # if !LST_invite_link
  #   LST_invite_link = await InviteLinkLST.create({
  #     season_id: season.meta.id
  #     league_id: season.rel.league
  #   })

  leagueDS = await db.collection('/leagues').doc(season.rel.league).get()
  league = pick(fbaH.deserialize(leagueDS.data()), [ 'meta.id', 'val.name', 'val.logo_url' ])

  if !season.val.isAdmin
    season = omit(season, ['val.settings'])

  if includes(roles, 'admin')
    # ctx.ok({ season, league, LSFA_invite_link, LST_invite_link })
    ctx.ok({ season, league })
  else
    ctx.ok({ season, league })
  return
