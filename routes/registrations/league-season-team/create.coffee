convert      = require('@/local/lib/convert')
every        = require('lodash/every')
fbaH         = require('@/local/lib/fba-helpers')
fbaI         = require('@/local/lib/fba-init')
find         = require('lodash/find')
isEmpty      = require('lodash/isEmpty')
isNumber     = require('lodash/isNumber')
map          = require('lodash/map')
merge        = require('lodash/merge')
ok           = require('@/local/lib/ok')
padStart     = require('lodash/padStart')
Payment      = require('@/local/models/payment')
some         = require('lodash/some')
trim         = require('lodash/trim')
User         = require('@/local/models/user')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')
{ hash }     = require('rsvp')

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { form, illst, code } = ctx.request.body

  if !uid
    ctx.unauthorized()
    return

  { fba, illst, user, } = await hash({
    fba:   fbaI()
    illst: fbaH.get('/invite-links', illst.meta.id)
    user:  User.getByUid(uid, { values: { meta: ['id'] }})
  })
  { league, season } = await hash({
    league: fbaH.get('/leagues', illst.rel.league)
    season: fbaH.get('/seasons', illst.rel.season)
  })

  db = fba.firestore()

  if (!every([
    ok.address(form.values.address)
    ok.displayName(form.values.display_name)
    ok.fullName(form.values.full_name)
    ok.gender(form.values.gender)
    ok.phone(form.values.address)
    ok.teamName(form.values.team_name)
    ok.teamNotes(form.values.team_notes)
  ]))
    ctx.badRequest()
    return

  { age, birthday, valid } = ok.birthday({
    day: form.values.birthday.day
    month: form.values.birthday.month
    year: form.values.birthday.year
  })
  if !valid || age < 18
    ctx.badRequest()
    return

  user_info =
    val:
      address: trim(form.values.address)
      birthday_clock_time: birthday.clock_time
      gender: form.values.gender
      display_name: trim(form.values.display_name)
      full_name: trim(form.values.full_name)
      phone: (trim(form.values.phone) ? '').replace(/[^0-9]/g, '')

  team_info =
    val:
      name: trim(form.values.team_name)
      notes: trim(form.values.team_notes)

  now = DateTime.local().setZone('utc').toISO()

  registration =
    meta:
      created_by: user.meta.id
      id: "registration-#{db.collection('/registrations').doc().id}"
      type: 'league-season-team'
      created_at: now
      updated_at: now
      deleted: false
      v: 4
    val:
      team_info: team_info
      user_info: user_info
    rel:
      invite_link: illst.meta.id
      league: league.meta.id
      payment: null
      price: find(season.val.settings.fees, { code: code, type: 'team-per-season' }).price ? null
      season: season.meta.id
      team: null
      user: user.meta.id

  if registration.rel.price
    payment = await Payment.create({
      rel:
        league: league.meta.id
        season: season.meta.id
        price: registration.rel.price
        payee: league.meta.id
        payee_type: 'league'
        season: season.meta.id
        registration: registration.meta.id
      meta:
        type: 'payment-registration-team-per-season'
    })
    registration.rel.payment = payment.meta.id

  await User.update(user.meta.id, user_info)

  _wb = db.batch()
  _wb.set(db.collection('/registrations').doc(registration.meta.id), fbaH.serialize(registration))
  _wb.set(db.collection("/leagues/#{league.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  _wb.set(db.collection("/seasons/#{season.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  _wb.set(db.collection("/users/#{user.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  await _wb.commit()


  ctx.ok({
    registration: { meta: { id: registration.meta.id }}
    payment: { val: { code: payment.val.code }}
  })
  return














