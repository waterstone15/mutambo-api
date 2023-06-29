FLI           = require '@/local/lib/flame-lib-init'
isEmpty       = require 'lodash/isEmpty'
isSafeInteger = require 'lodash/isSafeInteger'
isString      = require 'lodash/isString'
rand          = require '@stablelib/random'
trim          = require 'lodash/trim'
{ DateTime }  = require 'luxon'

Model = ->
  Flame = await FLI('main')

  M = Flame.model('InviteLink', {
    data:
      meta:
        v: '00000.00000.00000'
      rel:
        league: null
        season: null
        team:   null
        game:   null
      val:
        code: ((_d) ->
          dt = DateTime.local().setZone('utc').toFormat('yyyyooo')
          r  = rand.randomString(32)
          "#{r}-#{parseInt(dt).toString(36)}"
        )
        expires_at: null
        max_uses:   null
        password:   null
        uses:       0
    validators:
      rel:
        game:   (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
        league: (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
        season: (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
        team:   (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
      val:
        code:       (_v) -> isString(_v) && !isEmpty(trim(_v))
        expires_at: (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
        max_uses:   (_v) -> isEmpty(_v) || (isSafeInteger(_v) && _v >= 0)
        password:   (_v) -> isEmpty(_v) || (isString(_v) && !isEmpty(trim(_v)))
        uses:       (_v) -> isSafeInteger(_v) && (_v >= 0)

  })

  return M


module.exports = Model

