any          = require 'lodash/some'
includes     = require 'lodash/includes'
log          = require '@/local/lib/log'
{ all }      = require 'rsvp'

D2TModel     = require '@/local/models/flame-lib/division-to-team'
DModel       = require '@/local/models/flame-lib/division'
SModel       = require '@/local/models/flame-lib/season'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


module.exports = (ctx) ->
  
  uid  = ctx.state.fbUser.uid
  data = ctx.request.body

  tid  = data.team.meta.id
  did  = data.division.meta.id
  sid  = data.season.meta.id

  D2T      = await D2TModel()
  Division = await DModel()
  Season   = await SModel()
  Team     = await TModel()
  U2S      = await U2SModel()
  User     = await UModel()

  d2tQ = [
    [ 'where', 'rel.season', '==', sid ]
    [ 'where', 'rel.team',   '==', tid ]
  ]
  uQ = [[ 'where', 'rel.accounts', 'array-contains', uid ]]
 
  [ d2t, division, team, season, user ] = await (all [
    (D2T      .find d2tQ) .read()
    (Division .get  did)   .read()
    (Team     .get  tid)   .read()
    (Season   .get  sid)   .read()
    (User     .find uQ)   .read()
  ])

  u2sQ = [
    [ 'where', 'rel.season', '==', sid ]
    [ 'where', 'rel.user', '==', user.meta.id ]
  ]
  u2s = await (U2S.find u2sQ).read()

  if (any [
    (!u2s)
    (!(includes u2s.val.roles, 'admin'))
    ((did != 'none') && (division.rel.season != season.meta.id))
    (team.rel.season != season.meta.id)
  ]) 
    (ctx.badRequest {})
    return


  if (any [
    (!d2t && (did == 'none'))
    (d2t && (did != 'none') && (d2t.rel.division == division.meta.id))
  ])
    (ctx.ok {})
    return

  if (d2t && ((did == 'none') || (d2t.rel.division != division.meta.id)))
    d2t = (D2T.create d2t)
    await d2t.del().write()

  if did != 'none'
    d2t = (D2T.create {
      rel:
        division: division.meta.id
        season:   season.meta.id
        team:     team.meta.id
    })
    await d2t.save().write()

  (ctx.ok {})
  return



