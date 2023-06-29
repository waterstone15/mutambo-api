fs  = require('fs')
pug = require('pug')

module.exports = (->

  return ({ email, link }) ->
    t = pug.compileFile('local/templates/sign-in-with-email-link.pug')
    return t({ email, link })

)()
