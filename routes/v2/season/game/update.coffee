any          = require 'lodash/some'
eq           = require 'lodash/eq'
every        = require 'lodash/every'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
FLI          = require '@/local/lib/flame-lib-init'
get          = require 'lodash/get'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
isInteger    = require 'lodash/isInteger'
log          = require '@/local/lib/log'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reject       = require 'lodash/reject'
unionBy      = require 'lodash/unionBy'
uniq         = require 'lodash/uniq'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'

D2TModel     = require '@/local/models/flame-lib/division-to-team'
GModel       = require '@/local/models/flame-lib/game'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
STModel      = require '@/local/models/flame-lib/standings'
TModel       = require '@/local/models/flame-lib/team'
U2SModel     = require '@/local/models/flame-lib/user-to-season'
UModel       = require '@/local/models/flame-lib/user'


ite = (c, a, b = null) -> if c then a else b

module.exports = (ctx) ->
  
  { uid } = ctx.state.fbUser
  _game   = ctx.request.body

  Flame = await (FLI 'main')

  D2T       = await D2TModel()
  Game      = await GModel()
  League    = await LModel()
  Season    = await SModel()
  Standings = await STModel()
  Team      = await TModel()
  U2S       = await U2SModel()
  User      = await UModel()

  gQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', _game.meta.id ]
  ]
  sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'meta.id',      '==', _game.rel.season ]
  ]
  uQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.accounts', 'array-contains', uid ]
  ]

  gF = [
    'meta.id', 'rel.away_team', 'rel.home_team', 'rel.season',
    'val.location_text', 'val.start_clock_time', 'val.start_timezone'
  ]
  sF = [ 'meta.id', 'rel.league' ]
  uF = [ 'meta.id' ]
 
  [ game, season, user ] = await (all [
    Game   .find(gQ, gF) .read()
    Season .find(sQ, sF) .read()
    User   .find(uQ, uF) .read()
  ])

  ad2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', game.rel.away_team ]
  ]
  hd2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.team',     '==', game.rel.home_team ]
  ]
  u2sQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', _game.rel.season ]
    [ 'where', 'rel.user',     '==', user.meta.id ]
    [ 'where', 'val.roles',    'array-contains', 'admin' ]
  ]
  
  ad2tF = [ 'meta.id', 'rel.division' ]
  hd2tF = [ 'meta.id', 'rel.division' ]
  u2sF  = [ 'meta.id' ]
  
  [ ad2t, hd2t, u2s, ] = await (all [
    D2T .find(ad2tQ, ad2tF) .read()
    D2T .find(hd2tQ, hd2tF) .read()
    U2S .find(u2sQ, u2sF)   .read()
  ])

  if (any [
    !game
    (game.rel.season != _game.rel.season)
    !season
    !u2s
    !user
  ]) 
    (ctx.badRequest {})
    return

  changed =
    val:
      location_text:    !(eq game.val.location_text, _game.val.location_text)
      score: (
        !(eq (get game, 'val.score.home'), (get _game, 'val.score.home')) ||
        !(eq (get game, 'val.away.home'), (get _game, 'val.away.home'))
      )
      start_clock_time: !(eq game.val.start_clock_time, _game.val.start_clock_time)
      start_timezone:   !(eq game.val.start_timezone, _game.val.start_timezone)
  
  changed.val.standings = (every [
    changed.val.score
    (ad2t.rel.division != null)
    (ad2t.rel.division == hd2t.rel.division)
  ])

  game_fields = [
    ...(if changed.val.location_text    then [ 'val.location_text' ]    else [])
    ...(if changed.val.score            then [ 'val.score' ]            else [])
    ...(if changed.val.start_clock_time then [ 'val.start_clock_time' ] else [])
    ...(if changed.val.start_clock_time then [ 'val.start_utc' ]        else [])
    ...(if changed.val.start_timezone   then [ 'val.start_timezone' ]   else [])
    ...(if changed.val.start_timezone   then [ 'val.start_utc' ]        else [])
  ]
  game_fields = (uniq game_fields)

  fmt = "yyyy-LL-dd'T'hh:mm:ss"
  sct = ((get _game, 'val.start_clock_time') || '')
  stz = ((get _game, 'val.start_timezone') || 'utc')
  dt = (DateTime.fromFormat sct, fmt, { zone: stz })

  if changed.val.standings
    stQ = [
      [ 'where', 'meta.deleted', '==', false ]
      [ 'where', 'rel.division', '==', ad2t.rel.division ]
    ]
    stF = [ 'meta.id', 'val.results', ]
    _st = await Standings.find(stQ, stF).read()
    
    _result =
      rel:
        away_team: game.rel.away_team
        game: game.meta.id
        home_team: game.rel.home_team
      val:
        score:           
          away: (if (isInteger (get _game, 'val.score.away')) then (get _game, 'val.score.away') else null)
          home: (if (isInteger (get _game, 'val.score.home')) then (get _game, 'val.score.home') else null)

    if !_st
      st = (Standings.create {
        rel:
          division: hd2t.rel.division
          league:   season.rel.league
          season:   season.meta.id
        val:
          results: [_result]
      })
    else
      _st.val.results = (reject _st.val.results, { rel: game: _result.rel.game })
      _st.val.results = (unionBy [], _st.val.results, [_result], 'rel.game')
      st = (Standings.create (merge {}, _st))


  game = (Game.create {
    meta:
      id: _game.meta.id
    val:
      location_text:    if !(isEmpty _game.val.location_text) then _game.val.location_text else null
      start_clock_time: if dt.isValid then _game.val.start_clock_time else null
      start_timezone:   if dt.isValid then _game.val.start_timezone   else null
      start_utc:        if dt.isValid then dt.setZone('utc').toISO()  else null
      score:           
        away: (if (isInteger (get _game, 'val.score.away')) then (get _game, 'val.score.away') else null)
        home: (if (isInteger (get _game, 'val.score.home')) then (get _game, 'val.score.home') else null)
  })

  if !(game.ok game_fields)
    (ctx.badRequest {})
    return


  ok = await (Flame.transact (_t) ->
    await game.update(game_fields).write(_t)     if !(isEmpty game_fields)
    await st.update([ 'val.results' ]).write(_t) if (changed.val.standings && _st)
    await st.save().write(_t)                    if (changed.val.standings && !_st)
    return true
  )

  r = (ite ok, 'ok', 'badRequest')
  (ctx[r] {})
  return



