any          = require 'lodash/some'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

GModel       = require '@/local/models/flame-lib/game'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
UModel       = require '@/local/models/flame-lib/user'
U2SModel     = require '@/local/models/flame-lib/user-to-season'


module.exports = (ctx) ->
  
  { uid } = ctx.state.fbUser
  _game   = ctx.request.body

  Game         = await GModel()
  League       = await LModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToSeason = await U2SModel()

  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ season, user ] = await (all [
    Season .get(_game.rel.season) .read()
    User   .find(uQ)              .read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', _game.rel.season ]
    [ 'where', 'rel.user',   '==', user.meta.id ]
  ]
  user_to_season = await (UserToSeason.find u2sQ).read()

  if (any [
    !user
    !season
    !user_to_season
    !(includes user_to_season.val.roles, 'admin')
  ]) 
    (ctx.badRequest {})
    return

  sct = ((get _game, 'val.start_clock_time') || '')
  fmt = "yyyy-LL-dd'T'hh:mm:ss"
  tz  = { zone: ((get _game, 'val.start_timezone') || 'utc') }
  dt  = (DateTime.fromFormat sct, fmt, tz)

  game = (Game.create {
    ext:
      gameofficials: _game.ext.gameofficials || null
    val:
      location_text:    _game.val.location_text
      start_clock_time: if dt.isValid then _game.val.start_clock_time else null
      start_timezone:   if dt.isValid then _game.val.start_timezone   else null
      start_utc:        if dt.isValid then dt.setZone('utc').toISO()  else null
    rel:
      away_team: _game.rel.away_team
      home_team: _game.rel.home_team
      league:    season.rel.league
      season:    season.meta.id
  })

  if !game.ok()
    (ctx.badRequest {})
    return

  await game.save().write()

  (ctx.ok {})
  return



