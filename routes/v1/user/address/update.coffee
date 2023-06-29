fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
isEmpty      = require 'lodash/isEmpty'
isString     = require 'lodash/isString'
last         = require 'lodash/last'
sortBy       = require 'lodash/sortBy'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { address } = ctx.request.body

  address = trim(address)

  if !isString(address) || isEmpty(address)
    ctx.badRequest()
    return

  [ fba, user ] = await all([ fbaI(), User.getByUid(uid, { values: meta: [ 'id' ] }) ])
  db = fba.firestore()

  if !user.meta.id
    ctx.badRequest()
    return

  now = DateTime.local().setZone('utc')
  obj =
    val: address: address
    meta: updated_at: now.toISO()


  result = await db.runTransaction((T) ->
    userDR = db.collection('/users').doc(user.meta.id)
    userDS = await userDR.get()
    user = fbaH.deserialize(userDS.data())

    # history = user.meta.address_history ? []
    # history = sortBy(history, 'sunset_at')

    # updateAfter = (h) ->
    #   DateTime.fromISO(last(h).sunset_at).plus({ days: 45 })

    if address == user.val.address
      return Promise.resolve({})
    else
      T.update(userDR, fbaH.serialize(obj))
      return Promise.resolve({})
  #   else if isEmpty(history) && isEmpty(user.val.address)
  #     T.update(userDR, fbaH.serialize(obj))
  #     return Promise.resolve({})
  #   else if isEmpty(history) && !isEmpty(user.val.address)
  #     archive = { sunset_at: now.toISO(), val: user.val.address }
  #     obj.meta.address_history = fba.firestore.FieldValue.arrayUnion(archive)
  #     T.update(userDR, fbaH.serialize(obj))
  #     return Promise.resolve({})
  #   else if !isEmpty(history) && updateAfter(history) < now
  #     archive = { sunset_at: now.toISO(), val: user.val.address }
  #     obj.meta.address_history = fba.firestore.FieldValue.arrayUnion(archive)
  #     T.update(userDR, fbaH.serialize(obj))
  #     return Promise.resolve({})
  #   else
  #     days = updateAfter(history).diff(now, 'days').toObject().days
  #     return Promise.resolve({ wait_days: Math.ceil(days) })
  )

  ctx.ok(result)


