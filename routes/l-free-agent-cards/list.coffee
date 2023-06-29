fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
intersection = require('lodash/intersection')
isEmpty      = require('lodash/isEmpty')
map          = require('lodash/map')
merge        = require('lodash/merge')
pick         = require('lodash/pick')
reverse      = require('lodash/reverse')
sortBy       = require('lodash/sortBy')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { league_id } = ctx.request.query

  if !uid
    ctx.unauthorized()
    return

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: { meta: [ 'id' ] }})
  ])
  db = fba.firestore()

  [ card_ids_QS, roles_DS, ] = await all([
    db.collection("/leagues/#{league_id}/rel-player-cards").get()
    db.collection("/leagues/#{league_id}/users").doc(user.meta.id).get()
  ])

  roles = roles_DS.data?()?['access-control'] ? []

  free_agent_cards = await all(map(card_ids_QS.docs, (doc) ->
    cardDS = await db.collection('/player-cards').doc(doc.id).get()
    _card = fbaHelpers.deserialize(pick(cardDS.data(), [ 'meta-updated-at', 'rel-user', 'val-about', 'val-sport', 'meta-id' ]))
    _user = await User.get(_card.rel.user)
    _card.val.user =
      val:
        display_name: _user.val.display_name
        email: if !isEmpty(intersection(roles, [ 'admin', 'captain', 'manager', 'owner' ])) then _user.val.email else ''

    return _card
  ))

  free_agent_cards = reverse(sortBy(free_agent_cards, ['meta.updated_at']))

  ctx.ok({ free_agent_cards })
  return





