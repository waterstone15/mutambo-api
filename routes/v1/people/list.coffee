fbaI         = require '@/local/lib/fba-init'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser

  [ fba, user ] = await all([
    fbaI()
    User.getByUid(uid, { values: meta: ['id'] })
  ])
  db = fba.firestore()

  ctx.ok({})
  return


###
user-to-user =
  meta:
    created_at: now.toISO()
    deleted: false
    id: "user-to-user-#{db.collection('/id').doc().id}"
    type: 'user-to-user'
    updated_at: now.toISO()
    v: 1
  rel:
    user: <user_a>
    connection: <user_b>
  val:
    connection_is: [ 'opposing-team:manager', 'teammate:player', 'teammate:manager', 'friend', 'followed', 'following', 'league:admin', 'match:official' ]
    connection_display_name_insensitive: ''

###