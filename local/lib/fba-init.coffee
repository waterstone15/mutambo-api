fba   = require('firebase-admin')
merge = require('lodash/merge')
Vault = require('@/local/lib/arctic-vault')

module.exports = (->

  return (_config = {}) ->

    vault = await Vault.open()

    if !fba.apps.length
      config = merge({
        credential: fba.credential.cert(JSON.parse(vault.secrets.kv.FIREBASE_CONFIG))
        databaseURL: vault.secrets.kv.FIREBASE_DATABASE_URL
      }, _config)
      await fba.initializeApp(config)
    return fba

)()