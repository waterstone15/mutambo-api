fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
map          = require('lodash/map')
merge        = require('lodash/merge')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  values =
    meta: [ 'id' ]
    val: [ 'display_name', 'email' ]

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values })
  ])

  db = fba.firestore()

  cardsQS = await db
    .collection('/player-cards')
    .where('rel-user', '==', user.meta.id)
    .get()

  player_cards = await all(map(cardsQS.docs, (doc) ->
    return merge(fbaHelpers.deserialize(doc.data()), {
      val:
        user:
          val:
            email: user.val.email
            display_name: user.val.display_name
    })
  ))

  ctx.ok({ player_cards })
  return