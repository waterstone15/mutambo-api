Account      = require '@/local/models/account'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
get          = require 'lodash/get'
intersection = require 'lodash/intersection'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
isObject     = require 'lodash/isObject'
kebabCase    = require 'lodash/kebabCase'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
rand         = require '@stablelib/random'
SeasonToUser = require '@/local/models/season-to-user'
stripeI      = require 'stripe'
union        = require 'lodash/union'
User         = require '@/local/models/user'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (->


  _addManager = ({ team, user }) ->

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    team = await fbaH.get('/teams', team.meta.id)

    mt = { merge: true }
    ac = { 'access-control': fba.firestore.FieldValue.arrayUnion('manager') }

    s2u = await SeasonToUser.findOne({ season: { meta: { id: team.rel.season }}, user: user })
    if s2u
      await SeasonToUser.addRole({ season: { meta: { id: team.rel.season }}, user: user, roles: [ 'manager' ] })
    else
      await SeasonToUser.create({ roles: [ 'manager' ], season: { meta: { id: team.rel.season }}, user: user, })

    _wb = db.batch()
    _wb.set(db.collection("/teams").doc(team.meta.id), { 'val-manager-count': fba.firestore.FieldValue.increment(1) }, mt)

    _wb.set(db.collection("/leagues/#{team.rel.league}/users").doc(user.meta.id), ac, mt) if !!team.rel.league
    _wb.set(db.collection("/seasons/#{team.rel.season}/users").doc(user.meta.id), ac, mt) if !!team.rel.season
    _wb.set(db.collection("/teams/#{team.meta.id}/users").doc(user.meta.id), ac, mt)

    _wb.set(db.collection("/users/#{user.meta.id}/leagues").doc(team.rel.league), {}, mt)
    _wb.set(db.collection("/users/#{user.meta.id}/seasons").doc(team.rel.season), {}, mt)
    _wb.set(db.collection("/users/#{user.meta.id}/teams").doc(team.meta.id), {}, mt)

    await _wb.commit()

    return


  _addPlayer = ({ team, user }) ->

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    team = await fbaH.get('/teams', team.meta.id)

    mt = { merge: true }
    ac = { 'access-control': fba.firestore.FieldValue.arrayUnion('player') }

    s2u = await SeasonToUser.findOne({ season: { meta: { id: team.rel.season }}, user: user })
    if s2u
      await SeasonToUser.addRole({ season: { meta: { id: team.rel.season }}, user: user, roles: [ 'player' ] })
    else
      await SeasonToUser.create({ roles: [ 'player' ], season: { meta: { id: team.rel.season }}, user: user, })

    _wb = db.batch()
    _wb.set(db.collection("/teams").doc(team.meta.id), { 'val-player-count': fba.firestore.FieldValue.increment(1) }, mt)

    _wb.set(db.collection("/leagues/#{team.rel.league}/users").doc(user.meta.id), ac, mt) if !!team.rel.league
    _wb.set(db.collection("/seasons/#{team.rel.season}/users").doc(user.meta.id), ac, mt) if !!team.rel.season
    _wb.set(db.collection("/teams/#{team.meta.id}/users").doc(user.meta.id), ac, mt)

    _wb.set(db.collection("/users/#{user.meta.id}/leagues").doc(team.rel.league), {}, mt)
    _wb.set(db.collection("/users/#{user.meta.id}/seasons").doc(team.rel.season), {}, mt)
    _wb.set(db.collection("/users/#{user.meta.id}/teams").doc(team.meta.id), {}, mt)

    await _wb.commit()

    return



  _create = ({ league, payment, registration, season, user }) ->

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    team = merge({
      meta:
        created_at: now.toISO()
        created_by: get(user, 'meta.id') ? null
        deleted: false
        id: "team-#{db.collection('/teams').doc().id}"
        type: 'team-league-season'
        updated_at: now.toISO()
        v: 2
      rel:
        division: null
        league: get(league, 'meta.id') ? null
        manager_invite_link: null
        payment: get(payment, 'meta.id') ? null
        player_invite_link: null
        registration: get(registration, 'meta.id') ? null
        season: get(season, 'meta.id') ? null
      val:
        name: registration.val.team_info.val.name
        notes: registration.val.team_info.val.notes ? ''
    })

    if team.rel.season
      s2u = await SeasonToUser.findOne({ season: { meta: { id: team.rel.season }}, user: user })
      if s2u
        await SeasonToUser.addRole({ season: { meta: { id: team.rel.season }}, user: user, roles: [ 'manager' ] })
      else
        await SeasonToUser.create({ roles: [ 'manager' ], season: { meta: { id: team.rel.season }}, user: user, })

    _wb = db.batch()

    _wb.set(db.collection("/leagues/#{league.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
    _wb.set(db.collection("/leagues/#{league.meta.id}/teams").doc(team.meta.id), {}, { merge: true })
    _wb.set(db.collection("/leagues/#{league.meta.id}/users").doc(user.meta.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('captain') }, { merge: true })

    _wb.set(db.collection("/seasons/#{season.meta.id}/registrations").doc(registration.meta.id), {}, { merge: true })
    _wb.set(db.collection("/seasons/#{season.meta.id}/teams").doc(team.meta.id), {}, { merge: true })
    _wb.set(db.collection("/seasons/#{season.meta.id}/users").doc(user.meta.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('captain') }, { merge: true })

    _wb.set(db.collection("/teams").doc(team.meta.id), fbaH.serialize(team))
    _wb.set(db.collection("/teams/#{team.meta.id}/users").doc(user.meta.id), { 'access-control': fba.firestore.FieldValue.arrayUnion('captain') }, { merge: true })

    _wb.set(db.collection("/users/#{user.meta.id}/leagues").doc(league.meta.id), {}, { merge: true })
    _wb.set(db.collection("/users/#{user.meta.id}/seasons").doc(season.meta.id), {}, { merge: true })
    _wb.set(db.collection("/users/#{user.meta.id}/teams").doc(team.meta.id), {}, { merge: true })

    await _wb.commit()

    return team



  _get = (id, options = {}) ->
    fba = await fbaI()
    db  = fba.firestore()

    defaults = {}
    defaults.values = [
      'meta-created-at'
      'meta-created-by'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-division'
      'rel-league'
      'rel-player-invite-link'
      'rel-payment'
      'rel-registration'
      'rel-season'
      'val-name'
      'val-notes'
    ]

    values = defaults.values
    if isObject(options.values)
      ext    = map(values.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(values.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(values.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(values.val,  (v) -> "val-#{kebabCase(v)}")
      values = intersection(defaults.values, union(ext, meta, rel, val))
    else
      values = defaults.values

    team = await fbaH.get('/teams', id, { fields: values })

    return team



  # ---------------------------------------------------------------------------

  return {
    addManager: _addManager
    addPlayer:  _addPlayer
    create:     _create
    get:        _get
  }

)()
