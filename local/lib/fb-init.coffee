base64 = require('base-64')
firebase = require('firebase')

module.exports = (->

  return (name) ->
    if !firebase.apps.length
      config = JSON.parse(base64.decode(process.env.FIREBASE_CONFIG_BASE64))

      if name
        app = await firebase.initializeApp(config, name)
      else
        app = await firebase.initializeApp(config)

    return firebase

)()