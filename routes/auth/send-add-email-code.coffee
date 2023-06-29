{ all }  = require('rsvp')
fbaInit  = require('@/local/lib/fba-init')
isEmail  = require('validator/lib/isEmail')
isString = require('lodash/isString')
moment   = require('moment-timezone')
naclInit = require('@/local/lib/nacl-init')
postmark = require('postmark')
template = require('@/local/templates/email-code')
User     = require('@/local/models/user')


# currently unused.
module.exports = (ctx) ->

  { email } = ctx.request.body
  { uid } = ctx.state.fbUser

  [ nacl, fba, user ] = await all([
    naclInit()
    fbaInit()
    User.getByUid(uid, { values: [] })
  ])

  if !isString(email) || !isEmail(email)
    ctx.badRequest({ error: 'invalid-email' })
    return

  fbUser = await fba.auth().getUser(uid)
  if fbUser.email == email
    ctx.badRequest({ error: 'same-email' })
    return

  try
    newFbUser = await fba.auth().getUserByEmail(email)
    newUserDocSnap = await fba
      .firestore()
      .collection('/users')
      .doc(newFbUser.uid)
      .get()
    if newUserDocSnap.exists
      ctx.badRequest({ error: 'user-exists' })
      return
  catch error
    if error.errorInfo && error.errorInfo.code == 'auth/user-not-found'
      # If the user doesnt exist yet, great!
    else
      console.log(error)
      ctx.internalServerError({})
      return

  rand_bytes = nacl.random_bytes(8)
  rand_hex = nacl.to_hex(rand_bytes)
  rand_int = parseInt(rand_hex, 16)
  code1 = Number(rand_int).toString().slice(0, 4)
  code2 = Number(rand_int).toString().slice(4, 8)

  email_code =
    'code': "#{code1}#{code2}"
    'created-at': moment().toISOString()
    'created-by': user.id
    'email': email


  try
    postmarkEmail =
      'From': "hello@mutambo.com"
      'HtmlBody': template({ code1: code1, code2: code2 })
      'ReplyTo': "hello@mutambo.com"
      'Subject': 'Email Verification Code'
      'To': "#{email}"

    client = new postmark.ServerClient(process.env.POSTMARK_API_TOKEN)
    await all([
      fba.firestore().collection('/add-email-codes').doc().set(email_code)
      client.sendEmail(postmarkEmail)
    ])
  catch error
    console.log(error)

  ctx.ok({})
