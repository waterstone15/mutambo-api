fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
isEmpty      = require 'lodash/isEmpty'
padStart     = require 'lodash/padStart'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


validate =
  birthday: (bd) ->
    now = DateTime.local().setZone('utc')

    day   = padStart("#{bd.day}", 2, '0')
    month = padStart("#{bd.month}", 2, '0')
    year  = padStart("#{bd.year}", 4, '0')
    bday  = DateTime.fromISO("#{year}-#{month}-#{day}").setZone('utc')

    if !bday.isValid
      return false

    leeway   = 36
    max_age  = 150
    min_age  = min_age ? 0
    is_alive = now < bday.plus({ years: max_age })
    is_born  = now > bday
    is_old   = now > bday.plus({ years: min_age }).minus({ hours: leeway })
    return { bday: bday, ok: (is_born && is_alive && is_old) }

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { birthday } = ctx.request.body

  { bday, ok }  = validate.birthday(birthday)
  if !ok
    ctx.badRequest()
    return

  [ fba, user ] = await all([ fbaI(), User.getByUid(uid, { values: meta: [ 'id' ] }) ])
  db = fba.firestore()

  if !user.meta.id
    ctx.badRequest()
    return

  now = DateTime.local().setZone('utc')
  obj =
    val: birthday: bday.toISO()
    meta: updated_at: now.toISO()

  result = await db.runTransaction((T) ->
    userDR = db.collection('/users').doc(user.meta.id)
    userDS = await userDR.get()
    user = fbaH.deserialize(userDS.data())

    # history = user.meta.birthday_history ? []

    if obj.val.birthday == user.val.birthday
      return Promise.resolve({})
    else
      T.update(userDR, fbaH.serialize(obj))
      return Promise.resolve({})
    # else if isEmpty(history) && isEmpty(user.val.birthday)
    #   T.update(userDR, fbaH.serialize(obj))
    #   return Promise.resolve({})
    # else if isEmpty(history) && !isEmpty(user.val.birthday)
    #   archive = { sunset_at: now.toISO(), val: user.val.birthday }
    #   obj.meta.birthday_history = fba.firestore.FieldValue.arrayUnion(archive)
    #   T.update(userDR, fbaH.serialize(obj))
    #   return Promise.resolve({})
    # else if !isEmpty(history) && history.length < 4
    #   archive = { sunset_at: now.toISO(), val: user.val.birthday }
    #   obj.meta.birthday_history = fba.firestore.FieldValue.arrayUnion(archive)
    #   T.update(userDR, fbaH.serialize(obj))
    #   return Promise.resolve({})
    # else
    #   return Promise.resolve({ remaining: 0 })
  )

  ctx.ok(result)


