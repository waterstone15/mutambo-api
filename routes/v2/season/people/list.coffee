_            = require 'lodash'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isNumber     = require 'lodash/isNumber'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
set          = require 'lodash/set'
stripeI      = require 'stripe'
uniq         = require 'lodash/uniq'
Vault        = require '@/local/lib/arctic-vault'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'

module.exports = (ctx) ->
  
  { uid }             = ctx.state.fbUser
  { c, p, fs, season_id } = ctx.request.body

  vault  = await Vault.open()
  stripe = (stripeI vault.secrets.kv.STRIPE_SECRET_KEY)

  League  = await LModel()
  Season  = await SModel()
  Team    = await TModel()
  U2S     = await U2SModel()
  User    = await UModel()

  roles = [ 'admin', 'manager', 'player' ]
  role_ok = (includes roles, (get fs, 'role'))

  u2ssQ =
    constraints: [
      [ 'where', 'rel.season', '==', season_id ]
      ...(if role_ok then [[ 'where', 'val.roles', 'array-contains', fs.role ]] else [])
    ]
    cursor:
      position: if !!p then p
      value: if !!c then c
    sort:
      field: 'index.user_full_name_insensitive'
      order: 'low-to-high'
    size: 25

  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ u2ss, user ] = await (all [
    (U2S.page u2ssQ).read()
    (User.find uQ).read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', season_id ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2s = await (U2S.find u2sQ).read()

  if !u2s || !(includes u2s.val.roles, 'admin')
    (ctx.badRequest {})
    return

  p_ids = (filter (uniq (map u2ss.page.items, (_r) -> _r.rel.user)))

  [ people ] = await all([
    (User.getAll p_ids).read()
  ])

  u2ss.page.items = (map u2ss.page.items, (_u2s) ->
    person = (find people, { meta: { id: _u2s.rel.user }})

    p = (merge _u2s, (pick person, [ 'val.email', 'val.full_name', 'val.display_name' ]), {
      ui:
        roles: _(_u2s.val.roles).uniq().sortBy().map(_.capitalize).join(' • ')
    })

    return (pick p, [
      'meta.id',  'ui.roles', 
      'val.email', 'val.display_name', 'val.full_name', 'val.roles',
    ])
  )

  ctx.ok({ people: u2ss })
  return



