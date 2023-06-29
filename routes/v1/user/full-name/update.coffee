fbaI         = require '@/local/lib/fba-init'
isEmpty      = require 'lodash/isEmpty'
isString     = require 'lodash/isString'
last         = require 'lodash/last'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { full_name } = ctx.request.body

  full_name = trim(full_name)

  if !isString(full_name) || isEmpty(full_name)
    ctx.badRequest()
    return

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: [ 'id', 'full_name_history' ], val: [ 'full_name' ] })
  ])
  db = fba.firestore()

  if !user.meta.id
    ctx.badRequest()
    return

  # updateAfter = (h) ->
  #   DateTime.fromISO(last(h).sunset_at).plus({ days: 45 * (2 ** (h.length - 1)) })

  now = DateTime.local().setZone('utc')

  # history = sortBy(user.meta.official_name_history ? [], 'sunset_at')

  # has_history   = !isEmpty(history)
  # has_old_name  = !isEmpty(user.val.official_name)
  # history_valid = !isEmpty(last(history).sunset_at)
  new_name      = full_name
  old_name      = user.val.full_name
  # too_soon      = has_history && history_valid && (updateAfter(history) > now)

  response = {}

  # else if too_soon
  #   days = updateAfter(history).diff(now, 'days').toObject().days
  #   response = { wait_days: Math.ceil(days) }
  # else
  #   archive = { sunset_at: now.toISO(), val: user.val.official_name }
  #   obj =
  #     val:
  #       official_name: official_name
  #     meta: {
  #       ...(if (has_old_name && history_valid) then official_name_history: fba.firestore.FieldValue.arrayUnion(archive))
  #       ...(if (has_old_name && (!has_history || !history_valid)) then official_name_history: [archive])
  #     }
  #   await User.update(user.meta.id, obj)
  if old_name == new_name
    (->)() # no op
  else
    obj = { val: { full_name: full_name }}
    await User.update(user.meta.id, obj)

  ctx.ok(response)


