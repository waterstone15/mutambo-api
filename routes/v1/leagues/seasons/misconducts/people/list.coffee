_            = require 'lodash'
blackout     = require '@/local/lib/blackout'
capitalize   = require 'lodash/capitalize'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
first        = require 'lodash/first'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
join         = require 'lodash/join'
last         = require 'lodash/last'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
replace      = require 'lodash/replace'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { end_before, search_at, season_id, start_after, } = ctx.request.body

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
    endBefore: end_before
    filters: [
      [ 'rel-season', '==', season.meta.id ]
      [ 'val-access-control', 'array-contains-any', [ 'player', ]]
    ]
    limit: 5
    orderBy: [[ 'val-user-full-name-insensitive', "#{if !isEmpty(end_before) then 'desc' else 'asc'}" ]]
    searchAt: toLower(search_at)
    startAfter: start_after

  [ last_person, first_person, s2us ] = await all([
    fbaH.findOne('/seasons-to-users', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-user-full-name-insensitive', 'desc' ]]})
    fbaH.findOne('/seasons-to-users', { filters: [[ 'rel-season', '==', season.meta.id ]], orderBy: [[ 'val-user-full-name-insensitive', 'asc' ]]})
    fbaH.findAll('/seasons-to-users', q2)
  ])

  people = await all(map(s2us, (s2u) ->
    values = [
      'meta-deleted'
      'meta-id'
      'val-birthday-clock-time'
      'val-gender'
      'val-display-name'
      'val-full-name'
      'val-phone'
      'val-email'
    ]
    u = await User.get(s2u.rel.user, { values })

    if u.meta.deleted
      return null

    roles_formatted = _(s2u.val.access_control)
      .map((role) -> if (role == 'captain') then 'manager' else role)
      .uniq()
      .sortBy()
      .map(_.capitalize)
      .join(' • ')

    teamIDsQS = await db.collection("/users/#{u.meta.id}/teams").get()
    teams = await all(map(teamIDsQS.docs ? [], (doc) ->
      return fbaH.get('/teams', doc.id, { fields: [ 'meta-id', 'rel-season', 'val-name' ]})
    ))
    teams = sortBy(filter(teams, { rel: { season: season.meta.id }}), (t) -> toLower(t.val.name))

    return merge(u, {
      val:
        access_control: s2u.val.access_control
        teams: teams
        misconducts: []
      ui:
        email_blackout: blackout.email(u.val.emaiil ? '')
        email_masked: true
        phone_blackout: blackout.phone(u.val.phone ? '')
        phone_masked: true
        roles_formatted: roles_formatted
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
