any          = require 'lodash/some'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
sortBy       = require 'lodash/sortBy'
toLower      = require 'lodash/toLower'
{ all }      = require 'rsvp'

SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
U2TModel     = require '@/local/models/flame-lib/user-to-team'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->

  { uid }       = ctx.state.fbUser
  { player_id } = ctx.request.body
  { season_id } = ctx.request.body
  { team_id }   = ctx.request.body

  log player_id
  log season_id
  log team_id

  Season = await SModel()
  Team   = await TModel()
  U2S    = await U2SModel()
  U2T    = await U2TModel()
  User   = await UModel()

  p2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', team_id ]
    [ 'where', 'val.roles',    'array-contains-any', [ 'player' ] ]
    [ 'select', 'meta.id', 'rel.user', 'val.roles' ]
  ]
  pQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', player_id ]
  ]
  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', season_id ]
  ]
  tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', team_id ]
    [ 'where', 'rel.season',   '==', season_id ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  pF = [ 'meta.id', 'val.display_name', 'val.full_name' ]
  sF = [ 'meta.id' ]
  tF = [ 'meta.id', 'val.name' ]
  uF = [ 'meta.id' ]
 
  [ p2t, player, season, team, user ] = await (all [
    U2T    .find(p2tQ) .read()
    User   .find(pQ, pF)   .read()
    Season .find(sQ, sF)   .read()
    Team   .find(tQ, tF)   .read()
    User   .find(uQ, uF)   .read()
  ])

  if (any [ !p2t, !season, !team, !user ])
    (ctx.badRequest {})
    return

  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', season.meta.id ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  u2sF = [ 'meta.id' ]

  u2s = await U2S.find(u2sQ, u2sF).read()

  if !u2s
    (ctx.badRequest {})
    return

  (ctx.ok { player })
  return



