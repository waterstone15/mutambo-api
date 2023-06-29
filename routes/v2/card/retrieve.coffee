log      = require '@/local/lib/log'
merge    = require 'lodash/merge'
pick     = require 'lodash/pick'
{ all }  = require 'rsvp'

UModel = require '@/local/models/flame-lib/user'
CModel = require '@/local/models/flame-lib/card'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { sport, card_id } = ctx.request.body

  Card = await CModel()
  User = await UModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()

  if !user
    ctx.badRequest({})
    return

  cQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    ...(if !!card_id then [[ 'where', 'meta.id', '==', card_id ]] else [])
    ...(if !!sport   then [[ 'where', 'val.sport', '==', sport ]] else [])
  ]
  card = await Card.find(cQ).read()

  card = merge(card, {
    val:
      email: user.val.email
      display_name: user.val.display_name
  })

  ctx.ok({ card })
  return
