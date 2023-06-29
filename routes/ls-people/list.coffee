blackout     = require '@/local/lib/blackout'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
first        = require 'lodash/first'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
last         = require 'lodash/last'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { end_before, season_id, start_after } = ctx.request.query

  [ fba, season, user ] = await all([
    fbaI()
    fbaH.get('/seasons', season_id)
    User.getByUid(uid, { values: { meta: ['id'] }})
  ])
  db = fba.firestore()

  q1 =
    filters: [
      [ 'rel-season', '==', season.meta.id ]
      [ 'rel-user', '==', user.meta.id ]
      [ 'val-access-control', 'array-contains', 'admin' ]
    ]
  access = await fbaH.findOne('/seasons-to-users', q1)
  if access.empty
    ctx.unauthorized()
    return

  if !season || !user
    ctx.badRequest()
    return

  q2 =
    startAfter: start_after
    endBefore: end_before
    filters: [
      [ 'rel-season', '==', season.meta.id ]
      [ 'val-access-control', 'array-contains-any', [ 'captain', 'manager', 'player' ]]
    ]
    limit: 25
    orderBy: [[ 'val-user-full-name-insensitive', "#{if !isEmpty(end_before) then 'desc' else 'asc'}" ]]

  [ last_person, first_person, s2us ] = await all([
    fbaH.findOne('/seasons-to-users', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-user-full-name-insensitive', 'desc' ]]})
    fbaH.findOne('/seasons-to-users', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-user-full-name-insensitive', 'asc' ]]})
    fbaH.findAll('/seasons-to-users', q2)
  ])

  people = await all(map(s2us, (s2u) ->
    values = [
      'meta-deleted'
      'meta-id'
      'val-birthday'
      'val-display-name'
      'val-full-name'
      'val-gender'
      'val-phone'
      'val-email'
    ]
    u = await User.get(s2u.rel.user, { values })
    if u.meta.deleted
      return null
    else
      return merge(u, {
        val:
          access_control: s2u.val.access_control
        ui:
          email_blackout: blackout.email(u.val.email ? '')
          email_masked: true
          phone_blackout: blackout.phone(u.val.phone ? '')
          phone_masked: true
        rel:
          season_to_user: s2u.meta.id
      })
  ))
  people = filter(people)

  ctx.ok({
    end: last(people)
    first: first_person
    last: last_person
    people: people
    start: first(people)
  })
  return
