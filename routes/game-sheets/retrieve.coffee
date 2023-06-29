fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
filter       = require 'lodash/filter'
find         = require 'lodash/find'
includes     = require 'lodash/includes'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
pick         = require 'lodash/pick'
reverse      = require 'lodash/reverse'
sortBy       = require 'lodash/sortBy'
union        = require 'lodash/union'
unionBy      = require 'lodash/unionBy'
User         = require '@/local/models/user'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'
{ hash }     = require 'rsvp'

module.exports = (ctx) ->

  { id } = ctx.request.params

  fba = await fbaI()
  db = fba.firestore()

  game = await fbaH.get('/games', id)
  if !game
    ctx.badRequest()
    return

  away_misconducts = await fbaH.findAll('/misconducts', {
    filters: [
      ['rel-season', '==', game.rel.season]
      ['rel-team', '==', game.rel.away_team]
    ]
  })

  home_misconducts = await fbaH.findAll('/misconducts', {
    filters: [
      ['rel-season', '==', game.rel.season]
      ['rel-team', '==', game.rel.home_team]
    ]
  })

  [ away_team, division, home_team, league, season, homeUserIDsQS, awayUserIDsQS ] = await all([
    fbaH.get('/teams', game.rel.away_team)
    fbaH.get('/divisions', game.rel.division)
    fbaH.get('/teams', game.rel.home_team)
    fbaH.get('/leagues', game.rel.league)
    fbaH.get('/seasons', game.rel.season)
    db.collection("/teams/#{game.rel.home_team}/users").get()
    db.collection("/teams/#{game.rel.away_team}/users").get()
  ])
  if !home_team || !away_team || homeUserIDsQS.empty || awayUserIDsQS.empty
    ctx.badRequest()
    return

  game.val = merge(game.val, {
    away_team: pick(away_team, [ 'val.name' ])
    division: pick((division ? {}), [ 'val.name' ])
    home_team: pick(home_team, [ 'val.name' ])
    league: pick((league ? {}), [ 'val.name' ])
    season: pick((season ? {}), [ 'val.name' ])
  })

  addHomeUsersP = all(map(homeUserIDsQS.docs, (doc) ->
    if find(home_misconducts, { rel: { user: doc.id }, val: { status: 'suspended' }})
      return

    user = await fbaH.get('/users', doc.id)
    if includes(doc.data()['access-control'], 'player')
      game.val.home_team.val.players = sortBy(unionBy(game.val.home_team.val.players ? [], [{ name: user.val.full_name, id: user.meta.id }]), 'name')
    if includes(doc.data()['access-control'], 'captain')
      game.val.home_team.val.captains = sortBy(unionBy(game.val.home_team.val.captains ? [], [{ name: user.val.full_name, id: user.meta.id }]), 'name')
    return
  ))

  addAwayUsersP = all(map(awayUserIDsQS.docs, (doc) ->
    if find(away_misconducts, { rel: { user: doc.id }, val: { status: 'suspended' }})
      return

    user = await fbaH.get('/users', doc.id)
    if includes(doc.data()['access-control'], 'player')
      game.val.away_team.val.players = sortBy(unionBy(game.val.away_team.val.players ? [], [{ name: user.val.full_name, id: user.meta.id }]), 'name')
    if includes(doc.data()['access-control'], 'captain')
      game.val.away_team.val.captains = sortBy(unionBy(game.val.away_team.val.captains ? [], [{ name: user.val.full_name, id: user.meta.id }]), 'name')
    return
  ))

  await all([ addHomeUsersP, addAwayUsersP ])

  ctx.ok({ sheet: game })
  return
