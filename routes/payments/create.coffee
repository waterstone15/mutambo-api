convert         = require('@/local/lib/convert')
fbaHelpers      = require('@/local/lib/fba-helpers')
fbaInit         = require('@/local/lib/fba-init')
isEmpty         = require('lodash/isEmpty')
isNumber        = require('lodash/isNumber')
map             = require('lodash/map')
merge           = require('lodash/merge')
ok              = require('@/local/lib/ok')
padStart        = require('lodash/padStart')
rand            = require('@/local/lib/rand')
RegistrationLSP = require('@/local/models/registration/league-season-player')
User            = require('@/local/models/user')
{ all }         = require('rsvp')
{ DateTime }    = require('luxon')

module.exports = (ctx) ->
  now = DateTime.local().setZone('utc')
  ctx.ok({})
  return