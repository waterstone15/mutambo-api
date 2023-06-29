FLI      = require '@/local/lib/flame-lib-init'
includes = require 'lodash/includes'
isEmpty  = require 'lodash/isEmpty'
isString = require 'lodash/isString'
trim     = require 'lodash/trim'


Model = ->
  Flame = await FLI('main')

  M = Flame.model('Season', {
    data:
      meta:
        v: '00000.00000.00000'
      rel:
        league:   null
        settings: null
      val:
        name:   null
        status: 'active'
    validators:
      rel:
        league:   (_v) -> isString(_v) && !isEmpty(trim(_v))
        settings: (_v) -> isString(_v) && !isEmpty(trim(_v))
      val:
        name:   (_v) -> isString(_v) && !isEmpty(trim(_v))
        status: (_v) -> isString(_v) && includes([ 'active', 'canceled', 'ended', ], _v)
  })

  return M


module.exports = Model