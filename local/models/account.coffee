algolia      = require 'algoliasearch'
fbaHelpers   = require '@/local/lib/fba-helpers'
fbaInit      = require '@/local/lib/fba-init'
find         = require 'lodash/find'
intersection = require 'lodash/intersection'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

module.exports = (->

  # Agressively cache accounts since lookups are frequent
  #   and accounts are rarely (~never) updated.
  _accounts = []
  _cache = (obj) ->
    _accounts.splice(Math.floor(Math.random() * _accounts.length), 1) if _accounts.length >= 500
    _accounts = unionBy(_accounts, [obj], 'id')


  _get = (accountID) ->
    account = find(_cache, { accountID })
    if !account
      account = await fbaHelpers.get('/accounts', accountID)
      _cache(account)
    return account


  _create = (accountID) ->

    [ fba, vault ] = await all([ fbaInit(), Vault.open(), ])

    env    = vault.secrets.kv
    db     = fba.firestore()
    fbUser = await fba.auth().getUser(accountID)

    accountDR = undefined
    userID = undefined

    await db.runTransaction((T) ->
      accountDR = db.collection('/accounts').doc(accountID)

      [ accountDS, userQS ] = await all([
        T.get(accountDR)
        T.get(db.collection('/users').where('val-emails', 'array-contains', fbUser.email).limit(1))
      ])

      # If there is already an account for this email, nothing to do.
      # If there is not an account, but there is a user who has verified this email,
      #   then we need to create an account that points to the correct user.
      #   TODO: How is it possible to have a user, with a valid email, but no account?
      # If there is not an account, nor a user for this email
      #   then we need to create an account and user.
      if accountDS.exists
        return

      now = DateTime.local().setZone('utc')

      if !userQS.empty
        userID = userQS.docs[0].id
        userDR = db.collection('/users').doc(userID)
        T.create(accountDR, {
          'meta-created-at': now.toISO()
          'meta-deleted': false
          'meta-id': accountID
          'meta-type': 'account-firebase'
          'meta-updated-at': now.toISO()
          'meta-v': 2
          'rel-user': userID
        })
        T.update(userDR, {
          'val-accounts': fba.firestore.FieldValue.arrayUnion(accountID)
          'val-emails': fba.firestore.FieldValue.arrayUnion(fbUser.email)
        })
        return

      if !accountDS.exists && userQS.empty
        userID = "user-#{db.collection('/users').doc().id}"
        userDR = db.collection('/users').doc(userID)

        # client = algolia(env.ALGOLIA_APP_ID, env.ALGOLIA_ADMIN_API_KEY)
        # key = client.generateSecuredApiKey(env.ALGOLIA_SEARCH_ONLY_API_KEY, {
        #   filters: "-algolia-access-scope:user-#{userID}"
        # })

        T.create(accountDR, {
          'meta-created-at': now.toISO()
          'meta-deleted': false
          'meta-id': accountID
          'meta-type': 'account-firebase'
          'meta-updated-at': now.toISO()
          'meta-v': 2
          'rel-user': userID
        })
        T.create(userDR, {
          'meta-created-at': now.toISO()
          'meta-deleted': false
          'meta-id': userID
          'meta-type': 'user'
          'meta-updated-at': now.toISO()
          'meta-v': 3
          'rel-accounts': [accountID]
          'val-address': null
          # 'val-algolia-keys': { 'user-default': key }
          'val-birthday': null
          'val-display-name': null
          'val-display-name-history': []
          'val-email': fbUser.email
          'val-emails': [fbUser.email]
          'val-full-name': null
          'val-full-name-history': []
          'val-phone': null
        })
        return

    )

    return { id: accountDR.id, user: userID }

  # ---------------------------------------------------------------------------

  return {
    get: _get
    create: _create
  }

)()
