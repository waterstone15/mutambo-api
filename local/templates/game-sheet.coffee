fs  = require 'fs'
pug = require 'pug'

module.exports = (->

  return ({ sheet }) ->
    t = (pug.compileFile 'local/templates/game-sheet.pug')
    return (t { sheet })

)()
