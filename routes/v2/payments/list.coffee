FLI          = require '@/local/lib/flame-lib-init'
includes     = require 'lodash/includes'
isArray      = require 'lodash/isArray'
isEmpty      = require 'lodash/isEmpty'
isNull       = require 'lodash/isNull'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
money        = require 'currency.js'
pick         = require 'lodash/pick'
reduce       = require 'lodash/reduce'
sortBy       = require 'lodash/sortBy'
trim         = require 'lodash/trim'
union        = require 'lodash/union'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
PModel       = require '@/local/models/flame-lib/payment'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }  = ctx.state.fbUser
  { c, p } = ctx.request.body

  League       = await LModel()
  Payment      = await PModel()
  Season       = await SModel()
  Team         = await TModel()
  User         = await UModel()
  UserToTeam   = await U2TModel()

  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]
  user = await User.find(uQ).read()
  
  if !user
    (ctx.badRequest {})
    return

  pQ =
    constraints: [
      [ 'where', 'meta.created_at', '>=', '2023' ]
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.user', '==', user.meta.id ]
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    # fields: [ 'meta.created_at', 'meta.id', 'meta.type', 'rel.team', 'rel.user', 'val.roles' ]
    sort:
      field: 'meta.created_at'
      order: 'high-to-low'
    size: 10

  payments = await Payment.page(pQ).read()
  if !payments
    (ctx.ok { payments: {} })
    return

  # payment_acl =
  #   player:  [ 'meta.id', 'meta.updated_at', 'val.name', ]
  #   manager: [ 'meta.id', 'meta.updated_at', 'val.name', ]
  #   admin:   [ 'meta.id', 'meta.updated_at', 'val.name', ]

  payments.page.items = await (all (map payments.page.items, (_p) ->
    payment_paths = [
      'meta.created_at', 'meta.id',
      'val.code', 'val.currency', 'val.description', 'val.status', 'val.total'
    ]
    _p = (pick _p, payment_paths)
    return _p
  ))

  (ctx.ok { payments })
  return
