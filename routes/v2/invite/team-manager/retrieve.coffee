any          = require 'lodash/some'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
get          = require 'lodash/get'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

ICModel      = require '@/local/models/flame-lib/invite-code'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
SSModel      = require '@/local/models/flame-lib/season-settings'
TModel       = require '@/local/models/flame-lib/team'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { code } = ctx.request.body

  IC       = await ICModel()
  League   = await LModel()
  Season   = await SModel()
  Settings = await SSModel()
  Team     = await TModel()
  U2T      = await U2TModel()
  User     = await UModel()

  icQ = [
    [ 'where', 'val.code', '==', code ]
    [ 'where', 'meta.type', '==', 'invite-code/team-manager' ]
  ]
  
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  [ ic, user ] = await (all [
    (IC.find icQ).read()
    (User.find uQ).read()
  ])

  now = DateTime.local().setZone('utc')
  { expires_at } = ic.val

  if (any [
    (!user)
    (!ic)
    (ic.meta.deleted)
    (ic.val.uses > ic.val.max_uses)
    (expires_at && (now > (DateTime.fromISO expires_at)))
  ])
    (ctx.badRequest {})
    return

  u2tQ = [
    [ 'where', 'rel.team', '==', ic.rel.team ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  ssQ = [[ 'where', 'rel.season', '==', ic.rel.season ]]

  [ league, season, settings, team, u2t ] = await (all [
    League   .get(ic.rel.league) .read()
    Season   .get(ic.rel.season) .read()
    Settings .find(ssQ)          .read()
    Team     .get(ic.rel.team)   .read()
    U2T      .find(u2tQ)         .read()
  ])

  if (any [
    (!team)
    (!!league && (league.meta.deleted == true))
    (!!season && !settings)
    (!!season && (season.meta.deleted == true))
    (!!team   && (team.meta.deleted   == true))
  ])
    (ctx.badRequest {})
    return

  league   = (pick league,   [ 'meta.id', 'val.name' ])
  season   = (pick season,   [ 'meta.id', 'val.name' ])
  settings = (pick settings, [ 'val.required_info.manager' ])
  
  team   = (pick team,   [ 'meta.id', 'val.name' ])
  team   = (merge team, { val: { is_manager: (includes (get u2t, 'val.roles'), 'manager') }})

  itm = { val: { league, season, settings, team }}

  (ctx.ok { itm })
  return
