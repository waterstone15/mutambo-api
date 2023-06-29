convert      = require('@/local/lib/convert')
fbaHelpers   = require('@/local/lib/fba-helpers')
fbaInit      = require('@/local/lib/fba-init')
includes     = require('lodash/includes')
isEmpty      = require('lodash/isEmpty')
isNumber     = require('lodash/isNumber')
map          = require('lodash/map')
merge        = require('lodash/merge')
ok           = require('@/local/lib/ok')
padStart     = require('lodash/padStart')
trim         = require('lodash/trim')
User         = require('@/local/models/user')
SeasonToUser = require('@/local/models/season-to-user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  season = { val: { name: trim(ctx.request.body.season_name) }}
  league = { meta: { id: ctx.request.params.id }}

  if isEmpty(season.val.name) || !league.meta.id
    ctx.badRequest()
    return

  if !uid
    ctx.unauthorized()
    return

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: meta: [ 'id' ], val: [ 'display_name_insensitive', 'full_name_insensitive' ] })
  ])
  db = fba.firestore()

  rolesDS = await db.collection("/leagues/#{league.meta.id}/users").doc(user.meta.id).get()
  if !rolesDS.exists || !includes(rolesDS.data()['access-control'], 'owner')
    ctx.unauthorized()
    return

  now = DateTime.local().setZone('utc')

  season = merge(season, {
    meta:
      created_at: now.toISO()
      deleted: false
      id: "season-#{db.collection('/seasons').doc().id}"
      type: 'season'
      updated_at: now.toISO()
      v: 2
    rel:
      league: league.meta.id
    val:
      settings:
        fees:
          currency: 'usd'
          player_per_game: 0
          player_per_season: 0
          team_per_game: 0
          team_per_season: 0
        discounts: []
        required_information:
          admin:
            address: false
            birthday: false
            display_name: true
            email: true
            full_name: true
            gender: false
            phone: false
          player:
            address: false
            birthday: false
            display_name: true
            email: true
            full_name: true
            gender: false
            phone: false
          captain:
            address: false
            birthday: false
            display_name: true
            email: true
            full_name: true
            gender: false
            phone: false
  })

  s_obj = fbaHelpers.serialize(season)

  # Starting with a...
  # ...season ... you can find its users+roles and league
  # ...league ... you can find its seasons
  # ...user   ... you can find its seasons
  # ... in O(1) or O(n)

  await SeasonToUser.create({ role: 'admin', season: { meta: { id: team.rel.season }}, user: user, })

  _wb = db.batch()

  _wb.set(db.collection('/seasons').doc(season.meta.id), s_obj)
  _wb.set(db.collection("/seasons/#{season.meta.id}/users").doc(user.meta.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('admin') }, { merge: true })
  _wb.set(db.collection("/leagues/#{league.meta.id}/seasons").doc(season.meta.id), {}, { merge: true })
  _wb.set(db.collection("/users/#{user.meta.id}/seasons").doc(season.meta.id), {}, { merge: true })

  await _wb.commit()

  ctx.ok({ season: { meta: { id: season.meta.id }}})

