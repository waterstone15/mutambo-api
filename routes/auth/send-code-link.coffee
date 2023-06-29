chunk        = require 'lodash/chunk'
convert      = require '@/local/lib/convert'
fbaInit      = require '@/local/lib/fba-init'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
ok           = require '@/local/lib/ok'
postmark     = require 'postmark'
rand         = require '@/local/lib/rand'
template     = require '@/local/templates/sign-in-with-email-link'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

route = (ctx) ->

  vault = await Vault.open()

  { email, next } = ctx.request.body
  origin = ctx.request.headers.origin

  code_len = 32

  [ fba, code ] = await all([ fbaInit(), rand.base62(code_len) ])
  db = fba.firestore()

  emailOk = await ok.email(email)
  if (emailOk['email-verified'] != true && (
    emailOk['is-disposable'] == true ||
    emailOk['mx-ok'] == false
  ))
    ctx.badRequest({ error: 'invalid-email' })
    return

  code = map(chunk(code.split(''), (code_len / 4)), (_ck) -> _ck.join('')).join('-')
  now = DateTime.local().setZone('utc').toISO()

  link = "#{origin}/auth/auth-code-link?code=#{code}"
  (link = "#{link}&next=#{next}") if !!next
    

  await db.collection('/auth-codes').doc("auth-code-#{code}").set({
    'meta-created-at': now
    'meta-id': code
    'val-code': code
    'val-email': email
  })

  try
    postmarkEmail = {
      'From': 'hello@mutambo.com'
      'To': "#{email}"
      'Subject': 'Sign In Link'
      'ReplyTo': "hello@mutambo.com"
      'HtmlBody': template({ email, link })
    }
    client = new postmark.ServerClient(vault.secrets.kv.POSTMARK_API_TOKEN)
    await client.sendEmail(postmarkEmail)
  catch error
    console.log error

  ctx.ok({})
  return

module.exports = route
