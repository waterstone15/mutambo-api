nacl_factory = require('js-nacl')

naclInit = (->

  nacl = null

  return ->
    if !nacl
      nacl = await nacl_factory.instantiate(->)
    return nacl

)()


module.exports = naclInit
