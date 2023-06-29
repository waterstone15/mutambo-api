fbaInit  = require('@/local/lib/fba-init')
isEmail  = require('validator/lib/isEmail')
isString = require('lodash/isString')
isURL    = require('validator/lib/isURL')
ok       = require('@/local/lib/ok')
postmark = require('postmark')
replace  = require('lodash/replace')
template = require('@/local/templates/sign-in-with-email-link')

# Sends to the user an email with a sign-in link:
# 1. read 'email' address and 'url' from request's body
# 2. generate Firebase sign-in link from 'email' and 'url'
# 3. Postmarks to 'email' the generated link
module.exports = (ctx) ->

  { email, url } = ctx.request.body

  emailOk = await ok.email(email)
  if (emailOk['email-verified'] != true && (
    emailOk['is-owl-domain'] == true ||
    emailOk['is-disposable'] == true ||
    emailOk['mx-ok'] == false
  ))
    ctx.badRequest({ error: 'invalid-email' })
    return

  if !isString(url) || !isURL(url, { require_tld: false })
    ctx.badRequest({ error: 'invalid-url' })
    return

  try
    fba = await fbaInit()
    link = await fba.auth().generateSignInWithEmailLink(email, { url: url })

    link_url = new URL(link)
    url_url = new URL(url)
    link_url.host = url_url.host
    link_url.protocol = url_url.protocol
    link_url.pathname = replace(link_url.pathname, '__/', '')

    link_url.searchParams.append('confirm-path', '/sign-in-confirm')
    link = link_url.toString()

    postmarkEmail = {
      'From': "hello@mutambo.com"
      'To': "#{email}"
      'Subject': 'Sign in to Mutambo'
      'ReplyTo': "hello@mutambo.com"
      'HtmlBody': template({ email: email, link: link })
    }
    client = new postmark.ServerClient(process.env.POSTMARK_API_TOKEN)
    await client.sendEmail(postmarkEmail)
  catch error
    console.log(error)

  ctx.ok({})
