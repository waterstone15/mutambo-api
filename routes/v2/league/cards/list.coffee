get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'

C2LModel     = require '@/local/models/flame-lib/card-to-league'
CModel       = require '@/local/models/flame-lib/card'
U2LModel     = require '@/local/models/flame-lib/user-to-league'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { league_id, c, p } = ctx.request.body

  Card         = await CModel()
  CardToLeague = await C2LModel()
  User         = await UModel()
  UserToLeague = await U2LModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()
  
  u2lQ = [
    [ 'where', 'rel.league', '==', league_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2l  = await UserToLeague.find(u2lQ).read()
  
  if !user
    ctx.badRequest({})
    return

  c2lQ =
    constraints: [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'meta.updated_at', '>=', '2022-01' ]
      [ 'where', 'rel.league', '==', league_id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    fields: [ 'meta.id', 'meta.updated_at', 'rel.card', 'rel.league' ]
    sort:
      field: 'meta.updated_at'
      order: 'high-to-low'
    size: 10

  cards = await CardToLeague.page(c2lQ).read()

  l_roles = get(u2l, 'val.roles') ? []

  card_acl =
    public:  [ 'meta.id', 'meta.updated_at', 'val.about', 'val.sport' ]
    player:  [ 'meta.id', 'meta.updated_at', 'val.about', 'val.sport' ]
    captain: []
    manager: [ 'meta.id', 'meta.updated_at', 'val.about', 'val.sport' ]
    admin:   [ 'meta.id', 'meta.updated_at', 'val.about', 'val.sport' ]
  card_fields = reduce(l_roles, ((_acc, _role) ->
    uniq(union(_acc, card_acl[_role])))
  , card_acl.public)

  user_acl =
    public:  [ 'val.display_name' ]
    player:  [ 'val.display_name' ]
    captain: []
    manager: [ 'val.display_name', 'val.email' ]
    admin:   [ 'val.display_name', 'val.email', 'val.full_name' ]
  user_fields = reduce(l_roles, ((_acc, _role) ->
    uniq(union(_acc, user_acl[_role])))
  , user_acl.public)

  cards.page.items = await all(map(cards.page.items, (_c2l) ->
    card  = await Card.get(_c2l.rel.card).read()
    card_user = await User.get(card.rel.user).read()
    
    c = merge(pick(card, card_fields), pick(card_user, user_fields), {
      meta:
        updated_at: _c2l.meta.updated_at
      rel:
        card_to_league: _c2l.meta.id
    })
    return c
  ))

  ctx.ok({ cards })
  return
