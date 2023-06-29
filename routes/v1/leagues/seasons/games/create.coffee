fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
merge        = require 'lodash/merge'
SeasonToUser = require '@/local/models/season-to-user'
toLower      = require 'lodash/toLower'
toNumber     = require 'lodash/toNumber'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  data = ctx.request.body

  [ fba, season, user ] = await all([
    fbaI()
    fbaH.get('/seasons', data.season.meta.id)
    User.getByUid(uid, { values: { meta: [ 'id' ] }})
  ])
  db = fba.firestore()

  authorized = await SeasonToUser.anyRole({ season, user, roles: [ 'admin' ] })
  if !authorized
    ctx.unauthorized()
    return

  if !season || !user
    ctx.badRequest()
    return

  now = DateTime.local().setZone('utc')

  game =
    ext:
      gameofficials: if !!data.ext_id then toNumber(data.ext_id) else null
    meta:
      created_at: now.toISO()
      deleted: false
      id: "game-#{db.collection('/games').doc().id}"
      type: "game-league-season"
      updated_at: now.toISO()
      v: 2
    rel:
      away_team: data.away_team.meta.id
      division: data.away_team.val.division.meta.id
      home_team: data.home_team.meta.id
      league: season.rel.league
      season: season.meta.id
    val:
      location_text: if !!data.location_text then data.location_text else 'TBD'
      score:
        away: null
        home: null
      start_clock_time: data.datetime.clock
      start_timezone: data.datetime.zone
      start_iso: data.datetime.iso

  await db.collection('/games').doc(game.meta.id).set(fbaH.serialize(game))

  ctx.ok({})
  return
