addrs        = require 'email-addresses'
disposables  = require 'disposable-email-domains'
dns          = require 'dns'
fbaInit      = require '@/local/lib/fba-init'
includes     = require 'lodash/includes'
isEmail      = require 'validator/lib/isEmail'
isEmpty      = require 'lodash/isEmpty'
includes     = require 'lodash/includes'
isNumber     = require 'lodash/isNumber'
isString     = require 'lodash/isString'
map          = require 'lodash/map'
padStart     = require 'lodash/padStart'
some         = require 'lodash/some'
toInteger    = require 'lodash/toInteger'
trim         = require 'lodash/trim'
util         = require 'util'
{ DateTime } = require 'luxon'

address = (v) ->
  return isString(v) && !isEmpty(trim(v))

birthday = ({ year, month, day }) ->
  valid = false
  age = undefined
  clockTime = undefined

  day = padStart("#{day}", 2, '0')
  month = padStart("#{month}", 2, '0')
  year = "#{year}"

  now = DateTime.local().setZone('utc')
  bday = DateTime.fromISO("#{year}-#{month}-#{day}")

  if bday.isValid
    valid = true
    age = toInteger(now.diff(bday, 'years').years)
    clockTime = "#{bday.toISODate()}T00:00:00"

  return { age, birthday: { clockTime, 'clock-time': clockTime, clock_time: clockTime }, valid }

displayName = (v) ->
  return isString(v) && !isEmpty(trim(v))

email = (_email) ->

  fba = await fbaInit()

  address = addrs.parseOneAddress({ input: _email })?.address ? null
  result = {
    'address': address
    'email-verified': undefined
    'format-ok': isString(address) && isEmail(address)
    'is-catch-all': undefined
    'is-disposable': undefined
    'is-free': undefined
    'mx-ok': undefined
    'mx-records': []
    'original': _email
    'smtp-ok': undefined
  }

  if result['format-ok'] != true
    return result

  try
    user = await fba.auth().getUserByEmail(address)
  catch e
    (->)()
  result['email-verified'] = (user?.emailVerified == true)


  domain = result.address.split('@')[1]

  # Disposable Check
  result['is-disposable'] = some(disposables, (_d) -> includes(domain, _d))

  # MX Check
  try
    mx_results = await util.promisify(dns.resolveMx)(domain)
  catch e
    mx_results = []
  result['mx-records'] = map(mx_results, (mx) -> mx.exchange)
  result['mx-ok'] = (result['mx-records'] != [])

  if result['format-ok'] != true || result['mx-ok'] != true
    return result

  return result

fullName = (v) ->
  return isString(v) && !isEmpty(trim(v))

gender = (v) ->
  return includes(['male', 'female', 'other'], v)

phone = (v) ->
  return isString(v) && !isEmpty(trim(v))

teamName = (v) ->
  return isString(v) && !isEmpty(trim(v))

teamNotes = (v) ->
  return isString(v)

module.exports = {
  address
  birthday
  displayName
  email
  fullName
  gender
  phone
  teamName
  teamNotes
}
