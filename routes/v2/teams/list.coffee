_            = require 'lodash'
compact      = require 'lodash/compact'
each         = require 'lodash/each'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
isNull       = require 'lodash/isNull'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
sortBy       = require 'lodash/sortBy'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { c, p } = ctx.request.body

  League       = await LModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToTeam   = await U2TModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()
  
  if !user
    ctx.badRequest({})
    return

  u2tQ =
    constraints: [
      [ 'where', 'meta.updated_at', '>=', '2023' ]
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.user', '==', user.meta.id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    fields: [ 'meta.id', 'meta.updated_at',  'rel.team', 'rel.user', 'val.roles' ]
    sort:
      field: 'meta.updated_at'
      order: 'high-to-low'
    size: 10

  user_to_teams = await UserToTeam.page(u2tQ).read()

  if !user_to_teams
    (ctx.ok { teams: [] })
    return

  team_acl =
    player:  [ 'meta.id', 'meta.updated_at', 'val.name', ]
    manager: [ 'meta.id', 'meta.updated_at', 'val.name', ]
    admin:   [ 'meta.id', 'meta.updated_at', 'val.name', ]

  teams = await (all (map user_to_teams.page.items, (_u2t) ->
    if (isEmpty (get _u2t, 'val.roles'))
      return null

    team   = await Team.get(_u2t.rel.team).read()

    league = await League.get(team.rel.league).read()
    season = await Season.get(team.rel.season).read()

    league = (pick league, [ 'meta.id', 'val.name' ])
    season = (pick season, [ 'meta.id', 'val.name' ])

    team_fields = (reduce _u2t.val.roles, ((_acc, _role) ->
      (uniq (union _acc, team_acl[_role])))
    , team_acl.public)

    team = (pick team, team_fields)

    roles = (sortBy _u2t.val.roles)
    team = (merge team, {
      val:
        is_admin:   (includes roles, 'admin')
        is_captain: (includes roles, 'captain')
        is_manager: (includes roles, 'manager')
        is_player:  (includes roles, 'player')
        league:     league
        roles:      roles
        season:     season
    })
    return team
  ))
  teams = (compact teams)

  (ctx.ok { teams })
  return
