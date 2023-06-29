FLI      = require '@/local/lib/flame-lib-init'
includes = require 'lodash/includes'
isEmpty  = require 'lodash/isEmpty'
isNull   = require 'lodash/isNull'
isString = require 'lodash/isString'
trim     = require 'lodash/trim'


Model = ->
  Flame = await FLI('main')

  M = Flame.model('League', {
    data:
      ext:
        stripe_product:   null
      index:
        name_insensitive: 'League'
      meta:
        v:                '00000.00000.00000'
      val:
        description:      null
        name:             null
        sport:            null
        status:           'active'
        website:          null
    validators:
      ext:
        stripe_product:   (_v) -> isString(_v) && !isEmpty(trim(_v))
      index:
        name_insensitive: (_v) -> isString(_v) && !isEmpty(trim(_v))
      val:
        description:      (_v) -> isEmpty(trim(_v)) || (isString(_v) && !isEmpty(trim(_v)))
        name:             (_v) -> isEmpty(trim(_v)) || (isString(_v) && !isEmpty(trim(_v)))
        sport:            (_v) -> isString(_v) && !isEmpty(trim(_v))
        status:           (_v) -> isEmpty(_v) || includes([ 'active', 'canceled', 'ended', ], _v)
        website:          (_v) -> isEmpty(trim(_v)) || (isString(_v) && !isEmpty(trim(_v)))
  })

  return M


module.exports = Model