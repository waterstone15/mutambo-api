each         = require 'lodash/each'
find         = require 'lodash/find'
findIndex    = require 'lodash/findIndex'
get          = require 'lodash/get'
log          = require '@/local/lib/log'
merge        = require 'lodash/merge'
padStart     = require 'lodash/padStart'
reverse      = require 'lodash/reverse'
set          = require 'lodash/set'
sortBy       = require 'lodash/sortBy'
unionBy      = require 'lodash/unionBy'
{ all }      = require 'rsvp'

D2TModel     = require '@/local/models/flame-lib/division-to-team'
DModel       = require '@/local/models/flame-lib/division'
GModel       = require '@/local/models/flame-lib/game'
LModel       = require '@/local/models/flame-lib/league'
SModel       = require '@/local/models/flame-lib/season'
STModel      = require '@/local/models/flame-lib/standings'
TModel       = require '@/local/models/flame-lib/team'


module.exports = (ctx) ->
  
  lid = ctx.request.body.league_id
  sid = ctx.request.body.season_id


  D2T       = await D2TModel()
  Division  = await DModel()
  Game      = await GModel()
  League    = await LModel()
  Season    = await SModel()
  Standings = await STModel()
  Team      = await TModel()

  d2tQ = [
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
  ]
  dQ = [
    [ 'select', 'meta.id', 'val.name', ]
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
  ]
  stQ = [
    [ 'select', 'meta.id', 'rel.division', 'val.results', ]
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
  ]
  tQ = [
    [ 'select', 'meta.id', 'val.name', ]
    [ 'where', 'meta.deleted', '==', false ]
    [ 'where', 'rel.season',   '==', sid ]
    [ 'where', 'val.statuses', 'array-contains', 'registration-complete' ]
  ]

  lF = [ 'meta.id', 'val.logo_url', 'val.name' ]
  sF = [ 'meta.id', 'val.name' ]

  [ d2ts, divisions, league, season, standings, teams, ] = await (all [
    D2T       .list(d2tQ)   .read()
    Division  .list(dQ)     .read()
    League    .get(lid, lF) .read()
    Season    .get(sid, sF) .read()
    Standings .list(stQ)    .read()
    Team      .list(tQ)     .read()
  ])

  log league

  _standings = []

  (each standings, (_st) ->
    _d = (find divisions, { meta: id: _st.rel.division }) 
    st = val: { division: _d, teams: [] }
    
    (each _st.val.results, (_r) ->
      base = { val: { ga: 0, gf: 0, losses: 0, points: 0, ties: 0, wins: 0 }}

      _a = (find st.val.teams, { meta: id: _r.rel.away_team })
      if !_a
        _at = (find teams, { meta: id: _r.rel.away_team })
        _a  = (merge {}, base, _at)
        st.val.teams = (unionBy [], st.val.teams, [_a])
      
      _h = (find st.val.teams, { meta: id: _r.rel.home_team })
      if !_h
        _ht = (find teams, { meta: id: _r.rel.home_team })
        _h  = (merge {}, base, _ht)
        st.val.teams = (unionBy [], st.val.teams, [_h])

      _sc = _r.val.score

      if !_sc.away? || !_sc.home?
        return

      _ai = (findIndex st.val.teams, { meta: id: _r.rel.away_team })
      _sta = st.val.teams[_ai].val
      _sta.ga     += _sc.home
      _sta.gf     += _sc.away
      _sta.losses += if (_sc.home > _sc.away)  then 1 else 0
      _sta.points += if (_sc.home < _sc.away)  then 3 else 0
      _sta.points += if (_sc.home == _sc.away) then 1 else 0
      _sta.ties   += if (_sc.home == _sc.away) then 1 else 0
      _sta.wins   += if (_sc.home < _sc.away)  then 1 else 0
      
      _hi = (findIndex st.val.teams, { meta: id: _r.rel.home_team })
      _sth = st.val.teams[_hi].val
      _sth.ga     += _sc.away
      _sth.gf     += _sc.home
      _sth.losses += if (_sc.home < _sc.away)  then 1 else 0
      _sth.points += if (_sc.home > _sc.away)  then 3 else 0
      _sth.points += if (_sc.home == _sc.away) then 1 else 0
      _sth.ties   += if (_sc.home == _sc.away) then 1 else 0 
      _sth.wins   += if (_sc.home > _sc.away)  then 1 else 0

      return
    )
    st.val.teams = (reverse (sortBy st.val.teams, (_t) ->
      return "pts-#{(padStart _t.val.points, 9, '0')}" + 
        ".w-#{(padStart _t.val.wins, 9, '0')}" + 
        ".l-#{(padStart (999999999 - _t.val.losses), 9, '0')}" + 
        ".gf-#{(padStart _t.val.gf, 9, '0')}" + 
        ".ga-#{(padStart _t.val.ga, 9, '0')}"
    ))

    _standings = (unionBy [], _standings, [st], 'val.division.meta.id')
    return
  )

  _standings = (sortBy _standings, 'val.division.val.name')

  (ctx.ok { standings: _standings, league, season })
  return

