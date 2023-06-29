FLI      = require '@/local/lib/flame-lib-init'
log      = require '@/local/lib/log'
merge    = require 'lodash/merge'
map      = require 'lodash/map'
pick     = require 'lodash/pick'
{ all }  = require 'rsvp'

CModel   = require '@/local/models/flame-lib/card'
C2LModel = require '@/local/models/flame-lib/card-to-league'
UModel   = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { about, card_id, status, } = ctx.request.body

  Flame = await (FLI 'main')

  Card         = await CModel()
  CardToLeague = await C2LModel()
  User         = await UModel()

  c2lsQ = [[ 'where', 'rel.card', '==', card_id ]]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  [ card, c2ls, user ] = await (all [
    (Card.get card_id).read()
    (CardToLeague.findAll c2lsQ).read()
    (User.find uQ).read()
  ])

  if !user || !card
    (ctx.badRequest {})
    return

  c = (Card.create (merge card, { val: { about, status }}))

  if !c.ok()
    (ctx.badRequest {})
    return

  fields = [ 'val.about', 'val.status' ]

  ok = await (Flame.transact (_t) ->
    await (c.update fields).write(_t)

    await (all (map c2ls, (_c2l) ->
      c2l = (CardToLeague.create (merge _c2l, { meta: { deleted: (status == 'do-not-show') }}))
      await (c2l.update [ 'meta.deleted' ]).write(_t)
      return
    ))

    return true
  )
  

  if ok then (ctx.ok {}) else (ctx.badRequest {})
  return
