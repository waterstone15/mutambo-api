fbaHelpers   = require '@/local/lib/fba-helpers'
filter       = require 'lodash/filter'
FLI          = require '@/local/lib/flame-lib-init'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reverse      = require 'lodash/reverse'
sortBy       = require 'lodash/sortBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

module.exports = (ctx) ->

  Flame = await FLI('main')
  db = Flame.wildfire().firestore()
  
  { uid } = ctx.state.fbUser
  { id } = ctx.params

  user = await User.getByUid(uid)

  [ leagueDS, rolesDS, seasonsQS ] = await all([
    db.doc("/leagues/#{id}").get()
    db.doc("/leagues/#{id}/users/#{user.meta.id}").get()
    db.collection('/seasons').where('rel-league', '==', id).get()
  ])

  if !leagueDS.exists
    ctx.badRequest()
    return

  roles = sortBy(rolesDS.data?()?['access-control'] ? [])

  seasons = map(seasonsQS.docs, (DS) ->
    season = fbaHelpers.deserialize(DS.data())
    return pick(season, [ 'meta.id', 'meta.created_at', 'val.name' ])
  )


  _2022 = DateTime.fromISO('2022-01-01')
  seasons = reverse(sortBy(filter(seasons, (_s) -> DateTime.fromISO(_s.meta.created_at) > _2022), ['meta.created_at']))

  league = merge(fbaHelpers.deserialize(leagueDS.data()), {
    val:
      isAdmin:   includes(roles, 'admin')
      isCaptain: includes(roles, 'captain')
      isManager: includes(roles, 'manager')
      isOwner:   includes(roles, 'owner')
      isPlayer:  includes(roles, 'player')
      roles:     roles
  })

  ctx.ok({ league, seasons })
  return
