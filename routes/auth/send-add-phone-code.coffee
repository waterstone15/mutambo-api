fbaInit  = require('@/local/lib/fba-init')
isString = require('lodash/isString')
libPhone = require('google-libphonenumber')
moment   = require('moment-timezone')
naclInit = require('@/local/lib/nacl-init')
postmark = require('postmark')
# twilio   = require('twilio')
User     = require('@/local/models/user')
{ all }  = require('rsvp')


# currently unused.
module.exports = (ctx) ->

  ctx.ok({})
  return

  { phone } = ctx.request.body
  { uid } = ctx.state.fbUser

  [ nacl, fba, user ] = await all([
    naclInit()
    fbaInit()
    User.getByUid(uid, { values: [] })
  ])
  # sms = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN)

  phoneUtil = libPhone.PhoneNumberUtil.getInstance()
  PNF = libPhone.PhoneNumberFormat
  number = phoneUtil.parseAndKeepRawInput(phone, 'US')

  if !isString(phone) || !phoneUtil.isValidNumberForRegion(number, 'US')
    ctx.badRequest({ error: 'invalid-phone' })
    return

  phone = phoneUtil.format(number, PNF.E164)

  rand_bytes = nacl.random_bytes(8)
  rand_hex = nacl.to_hex(rand_bytes)
  rand_int = parseInt(rand_hex, 16)
  code1 = Number(rand_int).toString().slice(0, 4)
  code2 = Number(rand_int).toString().slice(4, 8)

  phone_code =
    'code': "#{code1}#{code2}"
    'created-at': moment().toISOString()
    'created-by': user.id
    'phone': phone

  msg =
    body: "Owl Mail code is: #{code1} #{code2}"
    from: '+16124452040'
    to: phone

  await all([
    fba.firestore().collection('/add-phone-codes').doc().set(phone_code)
    # sms.messages.create(msg)
  ])

  ctx.ok({})
