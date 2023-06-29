fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
intersection = require 'lodash/intersection'
isEmpty      = require 'lodash/isEmpty'
isObject     = require 'lodash/isObject'
kebabCase    = require 'lodash/kebabCase'
map          = require 'lodash/map'
pick         = require 'lodash/pick'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


S2U = (->


  _defaults =
    fields: [
      'meta-created-at'
      'meta-created-by'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-season'
      'rel-user'
      'val-access-control'
      'val-user-display-name-insensitive'
      'val-user-full-name-insensitive'
    ]


  _addRole = ({ season, user, role }) ->
    fba = await fbaI()
    db  = fba.firestore()

    q1 =
      filters: [
        [ 'rel-season', '==', season.meta.id ]
        [ 'rel-user',   '==', user.meta.id   ]
      ]
    s2u = await fbaH.findOne('/seasons-to-users', q1)

    if !s2u
      return

    if !includes([ 'admin', 'manager', 'captain', 'player', ], role)
      return

    await db.collection('/seasons-to-users').doc(s2u.meta.id).update({
      'val-access-control': fba.firestore.FieldValue.arrayUnion(role)
    })
    return


  _anyRole = ({ season, user, roles }) ->
    q1 =
      filters: [
        [ 'rel-season', '==', season.meta.id ]
        [ 'rel-user', '==', user.meta.id ]
        [ 'val-access-control', 'array-contains-any', roles ]
      ]
    access = await fbaH.findOne('/seasons-to-users', q1)
    return !access.empty


  _create = ({ season, user, roles }) ->
    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    s2u =
      meta:
        created_at: now.toISO()
        deleted: false
        id: "season-to-user-#{db.collection('/seasons-to-users').doc().id}"
        type: 'season-to-user'
        updated_at: now.toISO()
        v: 2
      rel:
        user: user.meta.id
        season: season.meta.id
      val:
        access_control: roles
        user_display_name_insensitive: user.val.display_name_insensitive
        user_full_name_insensitive: user.val.full_name_insensitive

    await db.collection('/seasons-to-users').doc(s2u.meta.id).set(fbaH.serialize(s2u))

    return s2u


  _findOne = ({ season, user }) ->
    fba = await fbaI()
    db  = fba.firestore()

    q =
      filters: [
        [ 'rel-season', '==', season.meta.id ]
        [ 'rel-user',   '==', user.meta.id   ]
      ]
    s2u = await fbaH.findOne('/seasons-to-users', q)

    return s2u


  _get = (id, options = {}) ->
    options.fields = options.values

    fields = options.fields
    if isObject(options.fields)
      ext    = map(fields.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(fields.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(fields.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(fields.val,  (v) -> "val-#{kebabCase(v)}")
      fields = intersection(_defaults.fields, union(ext, meta, rel, val))
    else
      fields = _defaults.fields

    season = await fbaH.get('/seasons', id, { fields: fields })
    return season


  _removeRole = ({ season, user, role }) ->
    fba = await fbaI()
    db  = fba.firestore()

    q1 =
      filters: [
        [ 'rel-season', '==', season.meta.id ]
        [ 'rel-user',   '==', user.meta.id   ]
      ]
    s2u = await fbaH.findOne('/seasons-to-users', q1)

    if !s2u
      return

    if !includes([ 'admin', 'manager', 'captain', 'player', ], role)
      return

    await db.collection('/seasons-to-users').doc(s2u.meta.id).update({
      'val-access-control': fba.firestore.FieldValue.arrayRemove(role)
    })
    return


  _update = ({ season, user, obj }) ->
    fba = await fbaI()
    db  = fba.firestore()

    q1 =
      filters: [
        [ 'rel-season', '==', season.meta.id ]
        [ 'rel-user',   '==', user.meta.id   ]
      ]
    s2u = await fbaH.findOne('/seasons-to-users', q1)

    if !s2u
      return

    now = DateTime.local().setZone('utc')
    updates =
      meta:
        updated_at: now.toISO()
      val: {
        ...(if !isEmpty(get(obj, 'val.access_control')) then { access_control: fba.firestore.FieldValue.arrayUnion(...obj.val.access_control) }),
        ...(if get(obj, 'val.user_display_name_insensitive') then { user_display_name_insensitive: obj.val.user_display_name_insensitive }),
        ...(if get(obj, 'val.user_full_name_insensitive') then { user_full_name_insensitive: obj.val.user_full_name_insensitive }),
      }

    updates_s = pick(fbaH.serialize(updates), _defaults.fields)
    await db.collection('/seasons-to-users').doc(s2u.meta.id).update(updates_s)
    return


  _updateAll = ({ user, obj = {}}) ->
    fba = await fbaI()
    db  = fba.firestore()

    now = DateTime.local().setZone('utc')

    q1 = { filters: [[ 'rel-user', '==', user.meta.id ]] }
    s2us = await fbaH.findAll('/seasons-to-users', q1)

    updates =
      meta:
        updated_at: now.toISO()
      val: {
        ...(if obj.val.display_name then { user_display_name_insensitive: toLower(trim(obj.val.display_name)) })
        ...(if obj.val.full_name then { user_full_name_insensitive: toLower(trim(obj.val.full_name)) })
      }

    await all(map(s2us, (s2u) ->
      updates_s = fbaH.serialize(updates)
      await db.collection('/seasons-to-users').doc(s2u.meta.id).update(updates_s)
    ))

    return



  # ---------------------------------------------------------------------------

  return {
    addRole:    _addRole
    anyRole:    _anyRole
    create:     _create
    findOne:    _findOne
    get:        _get
    removeRole: _removeRole
    update:     _update
    updateAll:  _updateAll
  }

)()


module.exports = S2U













