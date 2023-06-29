# algolia = require('algoliasearch')
# fbaInit = require('@/local/lib/fba-init')
# merge   = require('lodash/merge')
# moment  = require('moment-timezone')
# { all } = require('rsvp')

# module.exports = (ctx) ->

#   { uid } = ctx.state.fbUser

#   fba = await fbaInit()
#   fbUser = await fba.auth().getUser(uid)

#   db = fba.firestore()

#   await db.runTransaction((T) ->
#     accountDR = db.collection('/accounts').doc(uid)

#     [ accountDS, existingUserQS ] = await all([
#       T.get(accountDR)
#       T.get(db.collection('/users').where(
#         'emails', 'array-contains', fbUser.email).limit(1)
#       )
#     ])

#     if accountDS.exists
#       # If there is already an account for this email, nothing to do.
#       return
#     else if !existingUserQS.empty
#       # If there is not an account, but there is a user who has verified this email,
#       #    then we need to create an account that points to the correct user.
#       userid = existingUserQS.docs[0].id
#       userDR = db.collection('/users').doc(userid)
#       T.create(accountDR, { user: userid })
#       T.update(userDR, {
#         'accounts': fba.firestore.FieldValue.arrayUnion(uid),
#         'emails': fba.firestore.FieldValue.arrayUnion(fbUser.email),
#       })
#     else
#       # If there is not an account, nor a user for this email
#       #    then we need to create an account and user.
#       userid = "user-#{db.collection('/users').doc().id}"
#       userDR = db.collection('/users').doc(userid)

#       client = algolia(process.env.ALGOLIA_APP_ID, process.env.ALGOLIA_ADMIN_API_KEY)
#       scope = "user-#{user.id}"
#       key = client.generateSecuredApiKey(process.env.ALGOLIA_SEARCH_ONLY_API_KEY, { filters: "search-scope:#{scope}" })

#       T.create(accountDR, { user: userid })
#       T.create(userDR, {
#         'accounts': [uid]
#         'algolia-keys': { 'user-addresses': key }
#         'emails': [fbUser.email]
#         'email': fbUser.email
#       })

#     return
#   )


#   ctx.ok({})
