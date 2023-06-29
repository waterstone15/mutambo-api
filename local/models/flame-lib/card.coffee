FLI      = require '@/local/lib/flame-lib-init'
includes = require 'lodash/includes'
isEmpty  = require 'lodash/isEmpty'
isNull   = require 'lodash/isNull'
isString = require 'lodash/isString'
trim     = require 'lodash/trim'


Model = ->
  Flame = await (FLI 'main')

  sports = [
    'Football (Soccer)'
  ]
  
  statuses = [
    'show'
    'do-not-show'
  ]

  M = (Flame.model 'Card', {
    data:
      meta:
        v:     '00000.00000.00000'
      rel:
        user:   null
      val:
        about:  null
        sport:  null
        status: null
    validators:
      rel:
        user:   (_v) -> (isString _v) && !(isEmpty (trim _v))
      val:
        about:  (_v) -> (isString _v) && !(isEmpty (trim _v))
        sport:  (_v) -> (isString _v) && (includes sports, _v)
        status: (_v) -> (isNull _v)   || (includes statuses, _v)
  })

  return M


module.exports = Model