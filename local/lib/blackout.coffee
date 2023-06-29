indexOf = require('lodash/indexOf')
join    = require('lodash/join')
replace = require('lodash/replace')
split   = require('lodash/split')

blackout = (->

  return {

    email: (str) ->
      start = 1
      at = indexOf(str, '@')
      end = str.length
      arr = split(str, '')
      arr[start...at] = [0...(at - start)].fill('-')
      arr[(at + 2)...(end - 3)] = [(at + 2)...(end - 3)].fill('-')
      str = join(arr, '')

      return str

    phone: (str) ->
      start = 1
      end = str.length
      arr = split(str, '')
      arr[start...(end - 1)] = [0...(end - start - 1)].fill('-')
      str = join(arr, '')

      return str

  }

)()

module.exports = blackout
