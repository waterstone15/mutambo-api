fbaI         = require '@/local/lib/fba-init'
isEmpty      = require 'lodash/isEmpty'
isString     = require 'lodash/isString'
trim         = require 'lodash/trim'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { display_name } = ctx.request.body

  display_name = trim(display_name)

  if !isString(display_name) || isEmpty(display_name)
    ctx.badRequest()
    return

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: [ 'id' ] })
  ])
  db = fba.firestore()

  if !user.meta.id
    ctx.badRequest()
    return

  await User.update(user.meta.id, { val: { name: display_name, display_name: display_name }})

  ctx.ok({})
