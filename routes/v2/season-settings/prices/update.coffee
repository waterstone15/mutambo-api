_          = require 'lodash'
any        = require 'lodash/some'
currency   = require 'currency.js'
each       = require 'lodash/each'
flatPaths  = require '@/local/lib/flat-paths'
get        = require 'lodash/get'
hash       = require '@/local/lib/hash'
includes   = require 'lodash/includes'
isBoolean  = require 'lodash/isBoolean'
isCurrency = require 'validator/lib/isCurrency'
isNumber   = require 'lodash/isNumber'
floor      = require 'lodash/floor'
log        = require '@/local/lib/log'
merge      = require 'lodash/merge'
set        = require 'lodash/set'
SSModel    = require '@/local/models/flame-lib/season-settings'
toNumber   = require 'lodash/toNumber'
U2SModel   = require '@/local/models/flame-lib/user-to-season'
User       = require '@/local/models/user'
{ all }    = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  data = ctx.request.body

  season_id = data.rel.season

  fee_types = [
    'player_per_game'
    'player_per_season'
    'player_per_team'
    'team_per_game'
    'team_per_season'
  ]
  price_types = [ 'default', 'early_bird', 'gg_score', 'returning', ]
  paths = flatPaths(fee_types, price_types)

  currency_opts = 
    require_decimal: true
    allow_negatives: false

  prices = {}
  each(paths, (_p) ->
    num   = toNumber(get(data, "val.prices.#{_p}"))
    price = currency(floor(num, 2), { precision: 2 }).value
    set(prices, _p, price) if (isNumber(num) && (num >= 0))
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

  fields = [ 'val.prices' ]
  updates = _({})
    .set('val.prices', prices)
    .value()

  ss = SeasonSettings.create(merge(season_settings, updates))

  if !ss.ok(fields)
    ctx.badRequest({})
    return
  
  await ss.update(fields).write()

  ctx.ok({})
  return
