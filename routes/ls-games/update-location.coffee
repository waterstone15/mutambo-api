fbaI         = require('@/local/lib/fba-init')
fbaH         = require('@/local/lib/fba-helpers')
includes     = require('lodash/includes')
User         = require('@/local/models/user')
{ all }      = require('rsvp')


module.exports = (ctx) ->

  game_id           = ctx.params.id
  { location_text } = ctx.request.body
  { uid }           = ctx.state.fbUser

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: ['id'] })
  ])
  db = fba.firestore()

  game = await fbaH.get('/games', game_id)
  if !game
    ctx.badRequest()
    return

  accessDS = await db.collection("/seasons/#{game.rel.season}/users").doc(user.meta.id).get()
  if !includes(accessDS.data()['access-control'], 'admin')
    ctx.unauthorized()
    return

  _wb = db.batch()
  _wb.set(db.collection('/games').doc(game.meta.id), { 'val-location-text': location_text }, { merge: true })
  await _wb.commit()

  ctx.ok({})
  return
