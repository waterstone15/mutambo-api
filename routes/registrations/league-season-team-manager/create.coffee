convert      = require '@/local/lib/convert'
every        = require 'lodash/every'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
isNumber     = require 'lodash/isNumber'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
ok           = require '@/local/lib/ok'
padStart     = require 'lodash/padStart'
Payment      = require '@/local/models/payment'
pick         = require 'lodash/pick'
some         = require 'lodash/some'
Team         = require '@/local/models/team'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { form, illstm, code } = ctx.request.body

  if !uid
    ctx.unauthorized()
    return

  { fba, illstm, user, } = await hash({
    fba:   fbaI()
    illstm: fbaH.get('/invite-links', illstm.meta.id)
    user:  User.getByUid(uid, { values: { meta: ['id'] }})
  })
  { league, season, team } = await hash({
    league: fbaH.get('/leagues', illstm.rel.league)
    season: fbaH.get('/seasons', illstm.rel.season)
    team:   fbaH.get('/teams', illstm.rel.team)
  })

  db = fba.firestore()

  rolesDS = await db.collection("/teams/#{team.meta.id}/users").doc(user.meta.id).get()
  roles   = if rolesDS.exists then (rolesDS.data()['access-control'] ? []) else []
  if includes(roles, 'captain') || includes(roles, 'manager')
    ctx.ok({})
    return

  if (!every([
    ok.address(form.values.address)
    ok.displayName(form.values.display_name)
    ok.fullName(form.values.full_name)
    ok.gender(form.values.gender)
    ok.phone(form.values.address)
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

  now = DateTime.local().setZone('utc').toISO()

  registration =
    meta:
      created_by: user.meta.id
      id: "registration-#{db.collection('/registrations').doc().id}"
      type: 'registration-league-season-team-manager'
      created_at: now
      updated_at: now
      deleted: false
      v: 4
    val:
      user_info: user_info
    rel:
      invite_link: illstm.meta.id
      league: league.meta.id
      payment: null
      price: null
      season: season.meta.id
      team: team.meta.id
      user: user.meta.id

  if !registration.rel.price
    await Team.addManager({
      user: merge(pick(user, [ 'meta.id' ]), {
        val:
          display_name_insensitive: toLower(trim(form.values.display_name))
          full_name_insensitive: toLower(trim(form.values.full_name))
      })
      team: pick(team, [ 'meta.id' ])
    })

  # if registration.rel.price
  #   payment = await Payment.create({
  #     rel:
  #       league: league.meta.id
  #       season: season.meta.id
  #       price: registration.rel.price
  #       payee: league.meta.id
  #       payee_type: 'league'
  #       season: season.meta.id
  #       registration: registration.meta.id
  #     meta:
  #       type: 'payment-registration-team-per-season'
  #   })
  #   registration.rel.payment = payment.meta.id

  await User.update(user.meta.id, user_info)

  _wb = db.batch()
  _wb.set(db.collection('/registrations').doc(registration.meta.id), fbaH.serialize(registration))
  _wb.set(db.collection("/leagues/#{league.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  _wb.set(db.collection("/seasons/#{season.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  _wb.set(db.collection("/users/#{user.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
  await _wb.commit()

  res =
    registration: { meta: { id: registration.meta.id }}

  if registration.rel.price
    obj.payment = { val: { code: payment.val.code }}

  ctx.ok(res)
  return














