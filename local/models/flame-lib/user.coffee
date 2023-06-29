FLI          = require '@/local/lib/flame-lib-init'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
isNull       = require 'lodash/isNull'
isString     = require 'lodash/isString'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
trim         = require 'lodash/trim'
{ DateTime } = require 'luxon'


Model = ->
  Flame = await FLI('main')

  M = Flame.model('User', {
    data:
      meta:
        v: '00000.00000.00000'
      rel:
        accounts:             []
      val:
        address:              null
        address_history:      []
        birthday:             null
        birthday_history:     []
        display_name:         null
        display_name_history: []
        email:                null
        email_history:        []
        emails:               []
        full_name:            null
        full_name_history:    []
        gender:               null
        gender_history:       []
        phone:                null
        phone_history:        []
        phones:               []
    validators:
      rel:
        accounts:             (_v) -> !isEmpty(_v) && isArray(_v)
      val:
        address:              (_v) -> isNull(_v) || (!isEmpty(_v) && isString(trim(_v)))
        address_history:      (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        birthday: (_v) ->
          zeros    = { hour: 0, minute: 0, second: 0, millisecond: 0 }
          now      = DateTime.local().set(zeros).setZone('utc').toISO()
          bday     = DateTime.fromISO(_v, { zone: 'utc' }).toISO()
          is_valid = DateTime.fromISO(_v, { zone: 'utc' }).isValid
          return isNull(_v) || (!isEmpty(_v) && is_valid && (now > bday))

        birthday_history:     (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        display_name:         (_v) -> isNull(_v) || (!isEmpty(_v) && isString(trim(_v)))
        display_name_history: (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        email:                (_v) -> !isEmpty(_v) && isString(trim(_v))
        email_history:        (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        emails:               (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        full_name:            (_v) -> isNull(_v) || (!isEmpty(_v) && isString(trim(_v)))
        full_name_history:    (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        gender:               (_v) -> isNull(_v) || (includes([ 'female', 'male', 'other' ], _v))
        gender_history:       (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        phone:                (_v) -> isNull(_v) || (!isEmpty(_v) && isString(trim(_v)))
        phone_history:        (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
        phones:               (_v) -> isEmpty(_v) || (!isEmpty(_v) && isArray(_v))
  })

  return M


module.exports = Model

