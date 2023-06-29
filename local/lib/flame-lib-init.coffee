FL    = require 'flame-lib'
Vault = require '@/local/lib/arctic-vault'

module.exports = (->

  registered = false

  return ((_name) ->
    vault = await Vault.open()

    if !registered
      registered = true
      FL.register({
        'main': { service_account: JSON.parse(vault.secrets.kv.FIREBASE_CONFIG) }
      })

    return await FL.ignite(_name)
  )

)()

