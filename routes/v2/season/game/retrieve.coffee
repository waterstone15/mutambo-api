filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'
U2SModel     = require '@/local/models/flame-lib/user-to-season'


module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, game_id, season_id } = ctx.request.body

  Game         = await GModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToSeason = await U2SModel()

  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ game, season, user ] = await (all [
    Game   .get(game_id).read()
    Season .get(season_id).read()
    User   .find(uQ).read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user',   '==', user.meta.id ]
  ]
  user_to_season = await (UserToSeason.find u2sQ).read()

  if !user_to_season || !(includes user_to_season.val.roles, 'admin') || game.rel.season != season_id
    (ctx.badRequest {})
    return

  [ away_team, home_team ] = await (all [
    Team.get(game.rel.away_team).read()
    Team.get(game.rel.home_team).read()
  ])

  tF = [ 'meta.id', 'val.name', 'rel.division' ]

  away_team = (pick away_team, tF)
  home_team = (pick home_team, tF)

  time = DateTime.fromFormat(((get game, 'val.start_clock_time') || ''), "yyyy-MM-dd'T'HH:mm:ss", { zone: ((get game, 'val.start_timezone') || 'utc') })

  game = (merge game, {
    val:
      home_team: (pick home_team, tF)
      away_team: (pick away_team, tF)
    ui:
      date: if time.isValid then time.toFormat('yyyy.M.d') else null
      time: if time.isValid then time.toFormat('h:mm a')   else null
      zone: if time.isValid then time.toFormat('ZZZZ')     else null
  })

  game = (pick game, [
    'ext'
    'meta'
    'rel'
    'ui'
    'val'
  ])

  (ctx.ok { game })
  return



