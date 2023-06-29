_            = require 'lodash'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
sortBy       = require 'lodash/sortBy'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

SModel       = require '@/local/models/flame-lib/season'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { league_id } = ctx.request.body

  Season       = await SModel()
  User         = await UModel()
  UserToSeason = await U2SModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()
  
  if !user
    ctx.badRequest({})
    return

  sQ = [
    [ 'where', 'meta.created_at', '>', '2022' ]
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.league', '==', league_id ]
  ]
  seasons = await Season.list(sQ).read()
  seasons = _(seasons).sortBy('meta.created_at').reverse().value()
  
  season_acl =
    public: [ 'meta.deleted', 'meta.id', 'val.name', 'val.status' ]
    player: []
    captain: []
    manager: []
    admin: []

  seasons = await all(map(seasons, (_s) ->
    
    u2sQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.season', '==', _s.meta.id ]
      [ 'where', 'rel.user', '==', user.meta.id ]
    ]
    user_to_season = await UserToSeason.list(u2sQ).read()

    roles = sortBy(get(_s, 'val.roles') ? [])
    fields = reduce(roles, ((_acc, _role) ->
      uniq(union(_acc, season_acl[_role])))
    , season_acl.public)

    _s = pick(_s, fields)
    _s = merge(_s, {
      val:
        is_admin:   includes(roles, 'admin')
        is_captain: includes(roles, 'captain')
        is_manager: includes(roles, 'manager')
        is_player:  includes(roles, 'player')
        roles:      roles
    })
    return _s
  ))

  ctx.ok({ seasons })
  return
