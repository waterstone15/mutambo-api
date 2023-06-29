any          = require 'lodash/some'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
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
 
  [ game, season, user ] = await (all [
    Game   .get(_game.meta.id)    .read()
    Season .get(_game.rel.season) .read()
    User   .find(uQ)             .read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', _game.rel.season ]
    [ 'where', 'rel.user',   '==', user.meta.id ]
  ]
  user_to_season = await (UserToSeason.find u2sQ).read()

  if (any [
    !user
    !game
    !season
    !user_to_season
    !(includes user_to_season.val.roles, 'admin')
    (game.rel.season != _game.rel.season)
    _game.meta.deleted != true
  ]) 
    (ctx.badRequest {})
    return

  now = DateTime.local().setZone('utc')

  fields = [ 'meta.deleted', 'meta.deleted_at' ]

  game = (Game.create {
    meta:
      deleted:    _game.meta.deleted
      deleted_at: now.toISO()
      id:         _game.meta.id
  })

  if !(game.ok fields)
    (ctx.badRequest {})
    return

  await game.update(fields).write()

  (ctx.ok {})
  return



