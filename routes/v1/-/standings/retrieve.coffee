Division     = require '@/local/models/flame/division'
fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
first        = require 'lodash/first'
Flame        = require '@/local/lib/flame'
Game         = require '@/local/models/flame/game'
includes     = require 'lodash/includes'
isEmpty      = require 'lodash/isEmpty'
last         = require 'lodash/last'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reverse      = require 'lodash/reverse'
SeasonToUser = require '@/local/models/season-to-user'
sortBy       = require 'lodash/sortBy'
Standing     = require '@/local/models/flame/standing'
Team         = require '@/local/models/flame/team'
truncate     = require 'lodash/truncate'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'


module.exports = (ctx) ->

  { season_id } = ctx.request.body

  P1 = ->
    season = await fbaH.get('/seasons', season_id)
    league = await fbaH.get('/leagues', season.rel.league)
    league = pick(league, [ 'meta.id', 'val.name', 'val.logo_url' ])
    season = pick(season, [ 'meta.id', 'val.name' ])
    return { league, season }


  [ { league, season }, divisions, standings, teams ] = await all([
    P1()
    Division.list([[ 'where', 'rel-season', '==', season_id ]])
    Standing.list([[ 'where', 'rel-season', '==', season_id ]])
    Team.list([[ 'where', 'rel-season', '==', season_id ]])
  ])

  divisions = map(divisions.page_items, (t) -> pick(t, [ 'meta.id', 'val.name' ]))
  divisions = sortBy(divisions, [ 'val.name' ])
  standings = map(standings.page_items, (s) -> pick(s, [ 'meta.id', 'val', 'rel.division', 'rel.team' ]))
  teams = map(teams.page_items, (t) -> pick(t, [ 'meta.id', 'val.name', 'rel.division' ]))

  divisions = map(divisions, (d) ->
    division_standings = filter(standings, { rel: { division: d.meta.id }})
    division_standings = reverse(sortBy(division_standings, [
      'val.points'
      'val.wins'
      ((v) -> if (v.val.losses == 0) then 2 else (1 / v.val.losses))
      'val.goals_for'
      ((v) -> if (v.val.goals_against == 0) then 2 else (1 / v.val.goals_against))
    ]))
    division_standings = map(division_standings, (s) ->
      team = find(teams, { meta: { id: s.rel.team }})
      return merge(s, { val: { team: team }})
    )
    return merge(d, { val: { standings: division_standings }})
  )

  standings = { val: { divisions }}
  ctx.ok({ standings, league, season })
  return