fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
includes     = require 'lodash/includes'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'


module.exports = (ctx) ->

  { cancel_text, game_id } = ctx.request.body
  { uid } = ctx.state.fbUser

  if toLower(trim(cancel_text)) != 'cancel'
    ctx.badRequest()
    return

  [ fba, game, user ] = await all([
    fbaI()
    fbaH.get('/games', game_id)
    User.getByUid(uid, { values: meta: ['id'] })
  ])
  db = fba.firestore()

  if !game
    ctx.badRequest()
    return

  accessDS = await db.collection("/seasons/#{game.rel.season}/users").doc(user.meta.id).get()
  if !includes(accessDS.data()['access-control'], 'admin')
    ctx.unauthorized()
    return

  _wb = db.batch()
  _wb.set(db.collection('/games').doc(game.meta.id), { 'val-canceled': true }, { merge: true })
  await _wb.commit()

  ctx.ok({})
  return
