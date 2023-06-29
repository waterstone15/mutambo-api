_         = require 'lodash'
any       = require 'lodash/some'
each      = require 'lodash/each'
flatPaths = require '@/local/lib/flat-paths'
get       = require 'lodash/get'
hash      = require '@/local/lib/hash'
includes  = require 'lodash/includes'
isBoolean = require 'lodash/isBoolean'
log       = require '@/local/lib/log'
merge     = require 'lodash/merge'
set       = require 'lodash/set'
SSModel   = require '@/local/models/flame-lib/season-settings'
U2SModel  = require '@/local/models/flame-lib/user-to-season'
User      = require '@/local/models/user'
{ all }   = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  data = ctx.request.body

  season_id = data.rel.season

  roles = [ 'admin', 'manager', 'player' ]
  fields = [ 'address', 'birthday', 'email', 'full_name', 'gender', 'display_name', 'phone' ]
  paths = flatPaths(roles, fields)

  info = {}
  each(paths, (_p) ->
    i = get(data, "val.info.#{_p}")
    set(info, _p, i) if isBoolean(i) 
    return
  )

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
  ]))
    ctx.badRequest({})
    return

  if !includes(user_to_season.val.roles, 'admin')
    ctx.unauthorized({})
    return

  fields = [ 'val.required_info' ]
  updates = _({})
    .set('val.required_info', info)
    .value()

  ss = SeasonSettings.create(merge(season_settings, updates))

  if !ss.ok(fields)
    ctx.badRequest({})
    return
  
  await ss.update(fields).write()

  ctx.ok({})
  return
