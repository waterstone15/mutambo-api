blackout     = require '@/local/lib/blackout'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
toLower      = require 'lodash/toLower'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  # { uid } = ctx.state.fbUser
  # { game } = ctx.request.body
  # console.log game

  # [ fba, season, user ] = await all([
  #   fbaI()
  #   fbaH.get('/seasons', game.rel.season)
  #   User.getByUid(uid, { values: { meta: ['id'] }})
  # ])
  # db = fba.firestore()

  # rolesDS = await db.collection("/seasons/#{season.meta.id}/users").doc(user.meta.id).get()
  # roles   = rolesDS.data()['access-control']
  # if !includes(roles, 'admin')
  #   ctx.unauthorized()
  #   return

  # now = DateTime.local().setZone('utc')

  # if !season || !user
  #   ctx.badRequest()
  #   return

  # game =
  #   meta:
  #     created_at: now.toISO()
  #     deleted: false
  #     id: "game-#{db.collection('/games').doc().id}"
  #     type: 'game'
  #     updated_at: now.toISO()
  #     v: 2
  #   rel:
  #     league: season.rel.league
  #     season: season.meta.id
  #   val:
  #     location_text: ''

  # obj = fbaH.serialize(game)
  # await db.collection('/games').doc(game.meta.id).set(obj)

  ctx.ok({})
  return
