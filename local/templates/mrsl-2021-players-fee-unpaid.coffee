fs  = require('fs')
pug = require('pug')

module.exports = (->

  return (opts) ->
    t = pug.compileFile('local/templates/mrsl-2021-players-fee-unpaid.pug')
    return t(opts)

)()
