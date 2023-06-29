any          = require 'lodash/some'
each         = require 'lodash/each'
filter       = require 'lodash/filter'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
hash         = require '@/local/lib/hash'
includes     = require 'lodash/includes'
keys         = require 'lodash/keys'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
omit         = require 'lodash/omit'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
toLower      = require 'lodash/toLower'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
without      = require 'lodash/without'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

C2LModel = require '@/local/models/flame-lib/card-to-league'
CModel   = require '@/local/models/flame-lib/card'
ICModel  = require '@/local/models/flame-lib/invite-code'
LModel   = require '@/local/models/flame-lib/league'
UModel   = require '@/local/models/flame-lib/user'


ite = (a, b, c = null) -> if a then b else c

module.exports = (ctx) ->

  { uid } = ctx.state.fbUser
  { form, code } = ctx.request.body
  
  if !uid
    ctx.unauthorized()
    return

  Flame = await FLI('main')
  db    = await Flame.wildfire().firestore()
  
  Card         = await CModel()
  CardToLeague = await C2LModel()
  InviteCode   = await ICModel()
  League       = await LModel()
  User         = await UModel()

  icQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.type', '==', 'invite-code/league-free-agent' ]
    [ 'where', 'val.code', '==', code ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  [ ic, user ] = await all([
    InviteCode.find(icQ).read()
    User.find(uQ).read()
  ])

  now = DateTime.local().setZone('utc')
  { expires_at } = ic.val

  if (any([
    (!user)
    (user.meta.deleted)
    (!ic)
    (ic.meta.deleted)
    (ic.val.uses > ic.val.max_uses)
    (expires_at && (now > DateTime.fromISO(expires_at)))
  ]))
    ctx.badRequest({})
    return

  league = await League.get(ic.rel.league).read()
  if !league || league.meta.deleted
    ctx.badRequest({})
    return

  cQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.user', '==', user.meta.id ]
    [ 'where', 'val.sport', '==', league.val.sport ]
  ]
  c = await Card.find(cQ).read()
  
  card_fields  = ['about']
  card_updates = pick(form, card_fields)
  card_paths   = map(card_fields, (_f) -> "val.#{_f}")

  card = Card.create(merge((c ? {}), {
    rel:
      user: user.meta.id
    val:
      about: card_updates.about
      sport: league.val.sport
  }))

  
  user_fields  = [ 'display_name' ]
  user_updates = pick(form, user_fields)
  user_paths   = map(user_fields, (_f) -> "val.#{_f}")

  user = User.create(merge(user, { val: user_updates }))

  c2l_paths = [ 'meta.collection' ]
  c2lQ = [
    [ 'where', 'rel.card', '==', card.obj().meta.id ]
    [ 'where', 'rel.league', '==', league.meta.id ]
  ]
  c2l = await CardToLeague.find(c2lQ).read()
  card_to_league = CardToLeague.create(merge((c2l ? {}), {
    rel:
      card:   card.obj().meta.id
      league: league.meta.id
  }))


  if any([
    !user.ok(user_paths)
    (!!c   && !card.ok(card_paths))
    (!c    && !card.ok())
    (!!c2l && !card_to_league.ok(c2l_paths))
    (!c2l  && !card_to_league.ok())
  ])
    ctx.badRequest({})
    return
  

  ok = await Flame.transact((_t) ->
    await user.update(user_paths).write(_t)

    if !!c2l 
      await card_to_league.update(c2l_paths).write(_t)
    else
      await card_to_league.save().write(_t)

    if !!c 
      await card.update(card_paths).write(_t)
    else
      await card.save().write(_t)

    return true
  )

  if !!ok
    ctx.ok({})
  else
    ctx.badRequest({})
  return