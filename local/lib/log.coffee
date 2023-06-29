util = require 'node:util'

log = (_x) ->
  console.log(util.inspect(_x, {
    colors: true
    depth: 10
    maxArrayLength: 10000
    maxStringLength: 10000
  }))
  return

module.exports = log