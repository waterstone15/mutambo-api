fbaInit  = require('@/local/lib/fba-init')
isEmail  = require('validator/lib/isEmail')
isString = require('lodash/isString')
moment   = require('moment-timezone')
naclInit = require('@/local/lib/nacl-init')
postmark = require('postmark')
template = require('@/local/templates/add-email')
{ all }  = require('rsvp')


# currently unused.
module.exports = (ctx) ->

  [ nacl, fba ] = await all([ naclInit(), fbaInit() ])

  { email } = ctx.request.body
  { uid } = ctx.state.fbUser

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
    console.log(error)
    if error.errorInfo && error.errorInfo.code == 'auth/user-not-found'
      # If the user doesnt exist yet, great!
    else
      ctx.internalServerError({})
      return

  msg = JSON.stringify({
    email: email
    expires: moment.utc().add(5, 'm').format()
    uid: uid
  })

  k = nacl.random_bytes(nacl.crypto_secretbox_KEYBYTES)
  k_hex = nacl.to_hex(k)

  m = nacl.encode_utf8(msg)
  n = nacl.crypto_secretbox_random_nonce()
  n_hex = nacl.to_hex(n)

  c = nacl.crypto_secretbox(m, n, k)
  c_hex = nacl.to_hex(c)

  # generate predictable id tooverwrite db field for equivalent add-email attempts
  # Cut hex string down to 32 characters... 16^32 is plenty of entropy
  id = nacl.to_hex(nacl.crypto_hash_string("#{email}#{uid}")).slice(0,31)
  docRef = fba.firestore().collection('/add-email-tokens').doc(id)
  await docRef.set({ n_hex: n_hex, k_hex: k_hex, })

  url = "#{ctx.header.origin}/account/add-email-confirm"

  try
    link = await fba.auth()
      .generateSignInWithEmailLink(email, { url: url, })

    url_url = new URL(url)
    link_url = new URL(link)
    link_url.host = url_url.host
    link_url.protocol = url_url.protocol
    link_url.searchParams.append('confirm-path', '/account/add-email-confirm')
    link_url.searchParams.append('c_hex', c_hex)
    link_url.searchParams.append('id', docRef.id)
    link = link_url.toString()

    postmarkEmail =
      'From': "hello@mutambo.com"
      'To': "#{email}"
      'Subject': 'Add Email'
      'ReplyTo': "hello@mutambo.com"
      'HtmlBody': template({ email: email, link: link })

    client = new postmark.ServerClient(process.env.POSTMARK_API_TOKEN)
    await client.sendEmail(postmarkEmail)
  catch error
    console.log(error)

  ctx.ok({})
