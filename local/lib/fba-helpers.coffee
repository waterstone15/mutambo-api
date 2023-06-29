cloneDeep  = require 'lodash/cloneDeep'
fbaInit    = require '@/local/lib/fba-init'
forEach    = require 'lodash/forEach'
isArray    = require 'lodash/isArray'
isEmpty    = require 'lodash/isEmpty'
isNumber   = require 'lodash/isNumber'
isString   = require 'lodash/isString'
kebabCase  = require 'lodash/kebabCase'
keys       = require 'lodash/keys'
map        = require 'lodash/map'
mapKeys    = require 'lodash/mapKeys'
merge      = require 'lodash/merge'
pick       = require 'lodash/pick'
replace    = require 'lodash/replace'
reverse    = require 'lodash/reverse'
snakeCase  = require 'lodash/snakeCase'
startsWith = require 'lodash/startsWith'

module.exports = (->


  _deserialize = (_raw) ->
    raw = cloneDeep(_raw)
    obj = { ext: {}, meta: {}, rel: {}, val: {} }
    map(keys(raw), (k) ->
      k_snake = snakeCase(k)
      if startsWith(k_snake, 'ext_')
        obj.ext[replace(k_snake, 'ext_', '')] = raw[k]
      if startsWith(k_snake, 'meta_')
        obj.meta[replace(k_snake, 'meta_', '')] = raw[k]
      if startsWith(k_snake, 'rel_')
        obj.rel[replace(k_snake, 'rel_', '')] = raw[k]
      if startsWith(k_snake, 'val_')
        obj.val[replace(k_snake, 'val_', '')] = raw[k]
      return
    )
    return obj


  _find = (collection, filters = []) ->
    fba = await fbaInit()
    db = fba.firestore()

    if !isString(collection)
      return null

    Q = db.collection(collection)
    Q = Q.where(f[0], f[1], f[2]) for f in filters

    QS = await Q.get()
    if !QS.empty && QS.docs.length == 1
      return _deserialize(QS.docs[0].data())
    else
      return null


  _findAll = (collection, { endAt = null, endBefore = null, filters = [], limit = null, limitToLast = null, orderBy = [], searchAt = null, startAfter = null, startAt = null }) ->
    fba = await fbaInit()
    db = fba.firestore()

    if !isString(collection)
      return null

    Q = db.collection(collection)
    Q = Q.where(f[0], f[1], f[2]) for f in filters
    Q = Q.orderBy(o[0], (o[1] ? 'asc')) for o in orderBy
    if !isEmpty(endBefore)
      eb = await db.collection(collection).doc(endBefore).get()
      Q = Q.startAfter(eb)
    if !isEmpty(searchAt)
      Q = Q.startAt(searchAt)
    if !isEmpty(startAfter)
      sa = await db.collection(collection).doc(startAfter).get()
      Q = Q.startAfter(sa)
    Q = Q.limit(limit) if (isNumber(limit) && limit > 0)
    Q = Q.limitToLast(limitToLast) if (isNumber(limitToLast) && limitToLast > 0)

    QS = await Q.get()
    if !QS.empty
      xs = map(QS.docs, (doc) -> _deserialize(doc.data()))
      xs = reverse(xs) if !isEmpty(endBefore)
      return xs
    else
      return null


  _findBy = (path, field, id) ->
    fba = await fbaInit()
    db = fba.firestore()

    if !isString(path) || !isString(id)
      return null

    QS = await db.collection(path).where(field, '==', id).get()
    if !QS.empty && QS.docs.length == 1
      return QS.docs[0].data()
    else
      return null


  _findOne = (collection, {filters = [], orderBy = [] }) ->
    fba = await fbaInit()
    db = fba.firestore()

    if !isString(collection)
      return null

    Q = db.collection(collection)
    Q = Q.where(f[0], f[1], f[2]) for f in filters
    Q = Q.orderBy(o[0], (o[1] ? 'asc')) for o in orderBy
    Q = Q.limit(1)

    QS = await Q.get()
    if !QS.empty && QS.docs.length == 1
      return _deserialize(QS.docs[0].data())
    else
      return null


  _get = (path, id, opts) ->
    fields = opts?.fields

    fba = await fbaInit()
    db = fba.firestore()

    if !isString(path) || !isString(id)
      return null

    docSnap = await db.collection(path).doc(id).get()

    if docSnap.exists
      data = docSnap.data()
      data = pick(data, fields) if isArray(fields)
      return _deserialize(data)
    else
      return null


  _retrieve = (path, id) ->
    fba = await fbaInit()
    db = fba.firestore()

    if !isString(path) || !isString(id)
      return null

    docSnap = await db.collection(path).doc(id).get()
    if docSnap.exists
      return docSnap.data()
    else
      return null


  _serialize = (_obj) ->
    obj = cloneDeep(_obj)
    obj.ext = mapKeys(obj.ext, (v, k) -> kebabCase("ext_#{k}"))
    obj.meta = mapKeys(obj.meta, (v, k) -> kebabCase("meta_#{k}"))
    obj.rel = mapKeys(obj.rel, (v, k) -> kebabCase("rel_#{k}"))
    obj.val = mapKeys(obj.val, (v, k) -> kebabCase("val_#{k}"))
    fbdoc = merge(obj.ext, obj.meta, obj.rel, obj.val)
    return fbdoc


  # ---------------------------------------------------------------------------


  return {
    deserialize: _deserialize
    find:        _find
    findAll:     _findAll
    findBy:      _findBy
    findOne:     _findOne
    get:         _get
    retrieve:    _retrieve
    serialize:   _serialize
  }


)()
