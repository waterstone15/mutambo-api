filter   = require 'lodash/filter'
find     = require 'lodash/find'
FLI      = require '@/local/lib/flame-lib-init'
includes = require 'lodash/includes'
log      = require '@/local/lib/log'
map      = require 'lodash/map'
merge    = require 'lodash/merge'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
sortBy   = require 'lodash/sortBy'
toLower  = require 'lodash/toLower'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
{ all }  = require 'rsvp'

SSModel  = require '@/local/models/flame-lib/season-settings'
TModel   = require '@/local/models/flame-lib/team'
U2TModel = require '@/local/models/flame-lib/user-to-team'
UModel   = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }     = ctx.state.fbUser
  { team_id } = ctx.request.body

  Flame = await (FLI 'main')

  SS    = await SSModel()
  Team  = await TModel()
  U2T   = await U2TModel()
  User  = await UModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  [ team, user ] = await (all [
    Team.get(team_id).read()
    User.find(uQ).read()
  ])

  
  ssQ   = [[ 'where', 'rel.season', '==', team.rel.season ]]
  u2tsQ = [[ 'where', 'rel.team', '==', team.meta.id ]]

  [ ss, u2ts, ] = await (all [
    (SS.find ssQ).read()
    (U2T.list u2tsQ).read()
  ])
  
  u2t   = (find u2ts, { rel: user: user.meta.id })
  team  = (merge team, (pick u2t, [ 'val.roles' ]))

  if !user || !team || !u2t
    (ctx.badRequest {})
    return

  team = (merge team, { val: { season_settings: ss }})

  user_acl =
    player:  [ 'meta.id', 'val.display_name' ]
    captain: []
    manager: [ 'meta.id', 'val.display_name', 'val.email', 'val.full_name', ]

  team_acl =
    player:  [ 'meta.id', 'val.manager_count', 'val.name', 'val.player_count', 'val.roles', ]
    captain: []
    manager: [
      'meta.id',
      'val.manager_count', 'val.name', 'val.player_count', 'val.roles',
      'val.season_settings.val.registration_status.player_team'
    ]
  
  team_fields = (reduce team.val.roles, ((_acc, _role) ->
    return (uniq (union _acc, team_acl[_role]))
  ), [])
  
  user_fields = (reduce team.val.roles, ((_acc, _role) ->
    return (uniq (union _acc, user_acl[_role]))
  ), [])

  team = (merge (pick team, team_fields), {
    val:
      is_captain: (includes team.val.roles, 'captain')
      is_manager: (includes team.val.roles, 'manager')
      is_player:  (includes team.val.roles, 'player')
  })

  users = await (all (map u2ts, (_u2t) ->
    u = await User.get(_u2t.rel.user).read()
    return (merge (pick u, user_fields), (pick _u2t, [ 'val.roles' ]))
  ))
  users = (sortBy users, ((_u) -> "#{(toLower _u.val.full_name)}-#{(toLower _u.val.display_name)}"))
  
  team = (merge team, {
    val:
      managers: (filter users, ((_u) -> (includes _u.val.roles, 'manager')))
      players:  (filter users, ((_u) -> (includes _u.val.roles, 'player')))
      users:    users
  })

  (ctx.ok { team })
  return
