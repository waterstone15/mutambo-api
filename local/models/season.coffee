fbaH         = require('@/local/lib/fba-helpers')
intersection = require('lodash/intersection')
isObject     = require('lodash/isObject')
kebabCase    = require('lodash/kebabCase')
map          = require('lodash/map')
union        = require('lodash/union')


module.exports = (->

  _get = (id, options = {}) ->
    options.fields = options.values

    defaults =
      fields: [
        'meta-created-at'
        'meta-created-by'
        'meta-deleted'
        'meta-id'
        'meta-type'
        'meta-updated-at'
        'meta-v'
        'rel-league'
        'val-name'
        'val-settings'
      ]

    fields = options.fields
    if isObject(options.fields)
      ext    = map(fields.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(fields.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(fields.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(fields.val,  (v) -> "val-#{kebabCase(v)}")
      fields = intersection(defaults.fields, union(ext, meta, rel, val))
    else
      fields = defaults.fields

    season = await fbaH.get('/seasons', id, { fields: fields })
    return season



  # ---------------------------------------------------------------------------

  return {
    get: _get
  }

)()
