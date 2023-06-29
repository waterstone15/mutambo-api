FLI      = require '@/local/lib/flame-lib-init'
hash     = require '@/local/lib/hash'
log      = require '@/local/lib/log'
pick     = require 'lodash/pick'
reduce   = require 'lodash/reduce'
SSModel  = require '@/local/models/flame-lib/season-settings'
U2SModel = require '@/local/models/flame-lib/user-to-season'
union    = require 'lodash/union'
uniq     = require 'lodash/uniq'
User     = require '@/local/models/user'
{ all }  = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { season_id } = ctx.request.body

  SeasonSettings = await SSModel()
  UserToSeason = await U2SModel()

  user = await User.getByUid(uid)

  ssQ = [[ 'where', 'rel.season', '==', season_id ]]
  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ season_settings, user_to_season ] = await all([
    SeasonSettings.find(ssQ).read()
    UserToSeason.find(u2sQ).read()
  ])

  if !user_to_season || user_to_season.meta.deleted || !season_settings
    ctx.badRequest()
    return

  acl =
    public: [ 'meta.type', ]
    player: []
    captain: []
    manager: []
    admin: [ 'meta.id', 'val', ]

  fields = reduce(user_to_season.val.roles, ((acc, role) ->
    uniq(union(acc, acl[role])))
  , acl.public)

  season_settings = pick(season_settings, fields)

  ctx.ok({ season_settings })
  return
