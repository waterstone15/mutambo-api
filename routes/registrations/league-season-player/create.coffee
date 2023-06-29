# fbaHelpers      = require '@/local/lib/fba-helpers'
# fbaInit         = require '@/local/lib/fba-init'
# isEmpty         = require 'lodash/isEmpty'
# isNumber        = require 'lodash/isNumber'
# map             = require 'lodash/map'
# merge           = require 'lodash/merge'
# ok              = require '@/local/lib/ok'
# padStart        = require 'lodash/padStart'
# RegistrationLSP = require '@/local/models/registration/league-season-player'
# toLower         = require 'lodash/toLower'
# trim            = require 'lodash/trim'
# User            = require '@/local/models/user'
# { all }         = require 'rsvp'
# { DateTime }    = require 'luxon'

# module.exports = (ctx) ->

#   now = DateTime.local().setZone('utc')

#   { uid } = ctx.state.fbUser
#   body = ctx.request.body

#   if !uid
#     ctx.unauthorized()
#     return

#   body.user.displayName = trim(body.user.displayName)
#   body.user.fullName = trim(body.user.fullName)
#   body.user.address = trim(body.user.address)

#   if isEmpty(body.user.displayName) || isEmpty(body.user.fullName) || isEmpty(body.user.address)
#     ctx.badRequest()
#     return

#   { age, birthday, valid } = ok.birthday(body.user.birthday)
#   if !valid || age < 18
#     ctx.badRequest()
#     return

#   [ fba, user ] = await all([
#     fbaInit()
#     User.getByUid(uid, { values: [ 'email' ] })
#   ])
#   db = fba.firestore()

#   ilDS = await db.collection('/invite-links').doc(body.invite_link.id).get()
#   if !ilDS.exists
#     ctx.badRequest()
#     return

#   invite_link = ilDS.data()
#   rsQS = await db
#     .collection('/registration-settings')
#     .where('rel-league', '==', invite_link['rel-league'])
#     .where('rel-season', '==', invite_link['rel-season'])
#     .where('meta-type', '==', 'registration-settings-league-season-player')
#     .get()
#   if rsQS.empty
#     ctx.badRequest()
#     return

#   _reg =
#     meta:
#       created_at: now.toISO()
#       deleted: false
#       id: "registration-#{db.collection('/id').doc().id}"
#       type: 'registration-league-season-player'
#       updated_at: now.toISO()
#       v: 3
#     rel:
#       league: invite_link['rel-league']
#       season: invite_link['rel-season']
#       team: invite_link['rel-team']
#       user: user.id
#       registration_settings: rsQS.docs[0].id
#     val:
#       notes: ''
#       user_snapshot:
#         address: body.user.address
#         birthday_clock_time: birthday.clockTime
#         display_name: body.user.displayName
#         full_name: body.user.fullName
#         phone: body.user.phone
#       stripe_checkout_session: ''
#       stripe_payment_status: ''


#   u_updates = {}
#   (u_updates['val-address']                   = body.user.address             ) if !isEmpty(body.user.address)
#   (u_updates['val-birthday-clock-time']       = birthday.clockTime            ) if !isEmpty(birthday.clockTime)
#   (u_updates['val-name']                      = body.user.displayName         ) if !isEmpty(body.user.displayName)
#   (u_updates['val-name-insensitive']          = toLower(body.user.displayName)) if !isEmpty(body.user.displayName)
#   (u_updates['val-official-name']             = body.user.fullName            ) if !isEmpty(body.user.fullName)
#   (u_updates['val-official-name-insensitive'] = toLower(body.user.fullName)   ) if !isEmpty(body.user.fullName)
#   (u_updates['val-phone']                     = body.user.phone               ) if !isEmpty(body.user.phone)


#   _reg_s = fbaHelpers.serialize(_reg)

#   _wb = db.batch()
#   _wb.set(db.collection('/registrations').doc(_reg.meta.id), _reg_s, { merge: true })
#   _wb.set(db.collection("/leagues/#{_reg.rel.league}/registrations").doc(_reg.meta.id), { '-updated-at': now.toISO() }, { merge: true })
#   _wb.set(db.collection("/leagues/#{_reg.rel.league}/users").doc(user.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('player') }, { merge: true })
#   _wb.set(db.collection("/seasons/#{_reg.rel.season}/registrations").doc(_reg.meta.id), {'-updated-at': now.toISO() }, { merge: true })
#   _wb.set(db.collection("/seasons/#{_reg.rel.season}/users").doc(user.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('player') }, { merge: true })
#   _wb.set(db.collection("/teams/#{_reg.rel.team}/users").doc(user.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('player') }, { merge: true })
#   _wb.set(db.collection('/users').doc(user.id), u_updates, { merge: true })
#   _wb.set(db.collection("/users/#{user.id}/registrations").doc(_reg.meta.id), {'-updated-at': now.toISO() }, { merge: true })
#   _wb.set(db.collection("/users/#{user.id}/leagues").doc(_reg.rel.league), {'-updated-at': now.toISO() }, { merge: true })
#   _wb.set(db.collection("/users/#{user.id}/seasons").doc(_reg.rel.season), {'-updated-at': now.toISO() }, { merge: true })
#   _wb.set(db.collection("/users/#{user.id}/teams").doc(_reg.rel.team), {'-updated-at': now.toISO() }, { merge: true })
#   await _wb.commit()

#   ctx.ok({ id: _reg.meta.id })
#   return



