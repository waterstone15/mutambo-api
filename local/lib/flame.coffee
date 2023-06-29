camelCase    = require 'lodash/camelCase'
cloneDeep    = require 'lodash/cloneDeep'
each         = require 'lodash/each'
every        = require 'lodash/every'
fbaI         = require '@/local/lib/fba-init'
first        = require 'lodash/first'
get          = require 'lodash/get'
head         = require 'lodash/head'
isArray      = require 'lodash/isArray'
isBoolean    = require 'lodash/isBoolean'
isEmpty      = require 'lodash/isEmpty'
isInteger    = require 'lodash/isInteger'
isString     = require 'lodash/isString'
kebabCase    = require 'lodash/kebabCase'
keys         = require 'lodash/keys'
last         = require 'lodash/last'
map          = require 'lodash/map'
mapKeys      = require 'lodash/mapKeys'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
pluralize    = require 'pluralize'
rand         = require '@stablelib/random'
replace      = require 'lodash/replace'
set          = require 'lodash/set'
snakeCase    = require 'lodash/snakeCase'
some         = require 'lodash/some'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


flatten = (o) ->
  obj = {}
  each(keys(o), (k) ->
    obj = merge(obj, mapKeys(o[k], (v, kk) -> kebabCase("#{k}_#{kk}")))
  )
  return obj


expand = (o) ->
  obj = {}
  each(o, (v, k) ->
    key = replace(k, /\-(.*)/, '')
    sub = snakeCase(replace(k, /([^\-]*)\-/, ''))
    set(obj, "#{key}.#{sub}", v)
  )
  return obj


extend = (opts) ->
  if isEmpty(get(opts, 'obj.meta.type'))
    return null

  ok =
    meta:
      collection: (v) -> !isEmpty(v) && isString(v)
      created_at: (v) -> !isEmpty(v) && isString(v) && DateTime.fromISO(v).isValid
      deleted:    (v) -> isBoolean(v)
      id:         (v) -> !isEmpty(v) && isString(v)
      subtype:    (v) -> isEmpty || (!isEmpty(v) && isString(v))
      type:       (v) -> !isEmpty(v) && isString(v)
      updated_at: (v) -> !isEmpty(v) && isString(v) && DateTime.fromISO(v).isValid
      v:          (v) -> isInteger(v)
  ok = merge(ok, opts.ok)

  create = (_obj) ->
    now = DateTime.local().setZone('utc')

    obj =
      ext: {}
      index: {}
      meta:
        collection: opts.collection ? pluralize(opts.obj.meta.type)
        created_at: now.toISO()
        deleted: false
        id: "#{opts.obj.meta.type}-#{rand.randomString(32)}"
        subtype: null
        type: opts.obj.meta.type
        updated_at: now.toISO()
        v: 1
      rel: {}
      val: {}
    obj = merge(obj, opts.obj, _obj)


    return {

      flat: -> cloneDeep(flatten(this.obj()))

      obj: -> cloneDeep(obj)

      ok: (fields = null) ->
        if isArray(fields)
          ok = pick(ok, fields)
          obj = pick(obj, fields)

        ok_flat = flatten(ok)
        obj_flat = flatten(obj)

        kk = every(map(obj_flat, (val, key) ->
          good = ok_flat?[key]?(val)
          if !good
            err = { 'Key': key, 'Value': val, 'Error': 'Invalid Value.'}
            console.log 'All fields must have a successful ok validation function.'
            console.log "#{JSON.stringify(err, 2, 2)}"
          return good
        ))

        return kk

      save: ->
        if !this.ok()
          return null

        fba = await fbaI()
        db = fba.firestore()

        collection = this.obj().meta.collection
        try
          await db.collection(collection).doc(this.obj().meta.id).set(this.flat())
        catch e
          console.log e
          return null

        return this


      update: (fields) ->
        fields = union(fields, [ 'meta.updated_at' ])

        fba = await fbaI()
        db = fba.firestore()

        collection = this.obj().meta.collection

        updates = this.obj()
        updates = flatten(pick(updates, fields))

        try
          await db.collection(collection).doc(this.obj().meta.id).update(updates)
        catch e
          console.log e
          return null

        return true
    }





  return {

    create: create # creates a new instance of this model type with merged with the provided obj -> <Model>


    del: (id) ->
      fba = await fbaI()
      db  = fba.firestore()

      collection = opts.collection ? pluralize(opts.obj.meta.type)

      try
        await db.collection(collection).doc(id).delete()
      catch e
        console.log e
        return false

      return true



    find: (constraints = [], fields) -> # finds one model of this type using basic value filters -> <Model>
      constraint_types =  [
        'order-by'      # [ 'order-by', String <field-name>, String 'asc' | 'desc' ]
        'where'         # [ 'limit', String <field-name>, String <comparator>, String <field-value(s)> ]
      ]                 # <comparator> ::= '<' | '<=' | '==' | '>'  | '>=' | '!=' | 'array-contains' | 'array-contains-any' | 'in' | 'not-in'

      fba = await fbaI()
      db  = fba.firestore()

      collection = opts.collection ? pluralize(opts.obj.meta.type)

      Q = db.collection("/#{collection}")
      for c in constraints
        [ type, rest... ] = c
        if type == 'where' || type == 'order-by'
          Q = Q[camelCase(type)](rest...)
      Q = Q.limit(1)
      QS = await Q.get()

      if QS.empty
        return null
      else
        d = QS.docs[0].data()
        obj = expand(d)
        obj = pick(obj, fields) if !isEmpty(fields)
        return obj



    # @param id String
    # @param fields Array[String]
    # @return Promise -> Object or null
    get: (id, fields = []) ->
      fba = await fbaI()
      db  = fba.firestore()

      collection = opts.collection ? pluralize(opts.obj.meta.type)

      docSnap = await db.collection(collection).doc(id).get()
      if docSnap.exists
        d = docSnap.data()
        obj = expand(d)
        obj = pick(obj, fields) if !isEmpty(fields)
        return obj
      else
        return null


    list: (constraints = [], fields) -> # gets a list of models of this type based on the provided query constraints -> [<Model>]
      constraint_types =  [
        'end-at'        # [ 'end-at', String <document-id> ]
        'end-before'    # [ 'end-before', String <document-id> ]
        'limit'         # [ 'limit', Integer ]
        'limit-to-last' # [ 'limit-to-last', Integer ]
        'offset'        # [ 'offset', Integer ]
        'order-by'      # [ 'order-by', String <field-name>, String 'asc' | 'desc' ]
        'start-after'   # [ 'start-after', String <document-id> ]
        'start-at'      # [ 'start-at', String <document-id> ]
        'where'         # [ 'limit', String <field-name>, String <comparator>, String <field-value(s)> ]
      ]                 # <comparator> ::= '<' | '<=' | '==' | '>'  | '>=' | '!=' | 'array-contains' | 'array-contains-any' | 'in' | 'not-in'

      coll_first = null # first <document-id> in the collection
      coll_last  = null # last <document-id> in the collection
      page_end   = null # last <document-id> of the page
      page_items = null
      page_start = null # first <document-id> of the page

      fba = await fbaI()
      db  = fba.firestore()

      collection = opts.collection ? pluralize(opts.obj.meta.type)

      P1 = ->
        Q = db.collection("/#{collection}")
        for c in constraints
          [ type, rest... ] = c
          if type == 'where' || type == 'order-by'
            Q = Q[camelCase(type)](rest...)
        Q = Q.limit(1)
        QS = await Q.get()
        if !QS.empty
          coll_first = expand(QS.docs[0].data()).meta.id
        return coll_first

      P2 = ->
        Q = db.collection("/#{collection}")
        for c in constraints
          [ type, rest... ] = c
          if type == 'where' || type == 'order-by'
            [ stuff..., direction ] = rest
            Q = Q[camelCase(type)](stuff..., (if direction == 'asc' then 'desc' else 'asc'))
        Q = Q.limit(1)
        QS = await Q.get()
        if !QS.empty
          coll_last = expand(QS.docs[0].data()).meta.id
        return coll_last

      P3 = ->
        Q = db.collection("/#{collection}")
        for c in constraints
          [ type, rest... ] = c
          Q = Q[camelCase(type)](rest...)
        QS = await Q.get()

        if !QS.empty
          page_items = (expand(DS.data()) for DS in QS.docs)
          page_start = first(page_items).meta.id
          page_end   = last(page_items).meta.id
        return { page_items, page_start, page_end }


      [ coll_first, coll_last, { page_items, page_start, page_end } ] = await all([
        P1()
        P2()
        P3()
      ])

      return { coll_first, coll_last, page_items, page_start, page_end }


    ok: ok # validators for use anywhere
  }


Model = {
  extend
}

module.exports = Model

