fbaInit  = require('@/local/lib/fba-init')
isEmpty  = require('lodash/isEmpty')
isString = require('lodash/isString')
libphone = require('google-libphonenumber')
moment   = require('moment-timezone')
naclInit = require('@/local/lib/nacl-init')
replace  = require('lodash/replace')
User     = require('@/local/models/user')
{ all }  = require('rsvp')


# currently unused.
module.exports = (ctx) ->

  ctx.ok({})
  return

  { code } = ctx.request.body
  { uid } = ctx.state.fbUser

  code = replace(code, /\s/g, '')

  [ fba, user ] = await all([
    fbaInit()
    User.getByUid(uid, { values: [] })
  ])

  querySnap = await fba
    .firestore()
    .collection('/add-phone-codes')
    .where('created-by', '==', user.id)
    .where('code', '==', code)
    .get()

  if isEmpty(querySnap.docs) || querySnap.docs.length <= 0
    ctx.badRequest({ error: 'invalid-code' })
    return

  phone = querySnap.docs[0].data().phone
  expires = moment(querySnap.docs[0].data()['created-at']).add(5, 'm')

  if moment().isAfter(expires)
    ctx.badRequest({ error: 'code-expired' })
    return

  await fba.firestore().collection('/users').doc(user.id).update({
    # 'val-phones': fba.firestore.FieldValue.arrayUnion(phone)
    # 'val-primary-phone': phone
    'val-phone': phone
  })

  ctx.ok({})
  return
