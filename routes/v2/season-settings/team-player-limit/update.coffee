_         = require 'lodash'
any       = require 'lodash/some'
hash      = require '@/local/lib/hash'
includes  = require 'lodash/includes'
isInteger = require 'lodash/isInteger'
log       = require '@/local/lib/log'
merge     = require 'lodash/merge'
SSModel   = require '@/local/models/flame-lib/season-settings'
U2SModel  = require '@/local/models/flame-lib/user-to-season'
User      = require '@/local/models/user'
{ all }   = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  data = ctx.request.body

  season_id = data.rel.season
  limit = data.val.limit

  SeasonSettings = await SSModel()
  UserToSeason = await U2SModel()

  user = await User.getByUid uid

  ssQ = [[ 'where', 'rel.season', '==', season_id ]]
  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  [ season_settings, user_to_season ] = await all([
    SeasonSettings.find(ssQ).read()
    UserToSeason.find(u2sQ).read()
  ])

  if (any([
    !user_to_season
    user_to_season.meta.deleted
    !season_settings
    !isInteger(limit)
    !(1 <= limit <= 100)
    !(limit >= season_settings.val.team_limits.rostered_players)
  ]))
    ctx.badRequest({})
    return

  if !includes(user_to_season.val.roles, 'admin')
    ctx.unauthorized({})
    return

  fields = [ 'val.team_limits' ]
  updates = _({})
    .set('val.team_limits.team_players', limit)
    .value()
  
  ss = SeasonSettings.create(merge(season_settings, updates))

  if !ss.ok(fields)
    ctx.badRequest({})
    return
  
  await ss.update(fields).write()

  ctx.ok({})
  return
