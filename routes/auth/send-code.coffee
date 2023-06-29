chunk        = require('lodash/chunk')
fbaInit      = require('@/local/lib/fba-init')
map          = require('lodash/map')
ok           = require('@/local/lib/ok')
postmark     = require('postmark')
rand         = require('@/local/lib/rand')
template     = require('@/local/templates/auth-code')
{ all }      = require('rsvp')
{ DateTime } = require('luxon')

module.exports = (ctx) ->

  { email } = ctx.request.body

  code_len = 16
  chunks = 1

  [ fba, code ] = await all([ fbaInit(), rand.base62(code_len) ])
  db = fba.firestore()

  emailOk = await ok.email(email)
  if (emailOk['email-verified'] != true && (
    emailOk['is-owl-domain'] == true ||
    emailOk['is-disposable'] == true ||
    emailOk['mx-ok'] == false
  ))
    ctx.badRequest({ error: 'invalid-email' })
    return

  code = map(chunk(code.split(''), (code_len / chunks)), (_ck) -> _ck.join('')).join('-')
  now = DateTime.local().setZone('utc').toISO()

  await db.collection('/auth-codes').doc("auth-code-#{code}").set({
    'meta-created-at': now
    'meta-id': code
    'val-code': code
    'val-email': email
  })

  try
    postmarkEmail = {
      'From': "hello@mutambo.com"
      'To': "#{email}"
      'Subject': 'Sign In Code'
      'ReplyTo': "hello@mutambo.com"
      'HtmlBody': template({ email, code })
    }
    client = new postmark.ServerClient(process.env.POSTMARK_API_TOKEN)
    await client.sendEmail(postmarkEmail)
  catch error
    console.log(error)

  ctx.ok({})