fbaH         = require '@/local/lib/fba-helpers'
fbaI         = require '@/local/lib/fba-init'
get          = require 'lodash/get'
intersection = require 'lodash/intersection'
isObject     = require 'lodash/isObject'
kebabCase    = require 'lodash/kebabCase'
map          = require 'lodash/map'
merge        = require 'lodash/merge'
union        = require 'lodash/union'
{ all }      = require 'rsvp'
{ DateTime } = require 'luxon'


module.exports = (->


  _create = ({ away_team, data, division, home_team, league, season }) ->

    fba = await fbaI()
    db = fba.firestore()

    now = DateTime.local().setZone('utc')

    game = merge({
      ext:
        gameofficials: data.gameofficials ? null
      meta:
        created_at: now.toISO()
        deleted: false
        id: "game-#{db.collection('/games').doc().id}"
        type: 'game-league-season'
        updated_at: now.toISO()
        v: 2
      rel:
        away_team: get(away_team, 'meta.id') ? null
        division: get(division, 'meta.id') ? null
        home_team: get(home_team, 'meta.id') ? null
        league: get(league, 'meta.id') ? null
        season: get(season, 'meta.id') ? null
      val:
        location_text: data.location_text ? null
        score: { home: null, away: null }
        start_clock_time: data.start_clock_time ? null
        start_timezone: data.start_timezone ? null
        canceled: data.canceled ? false
    })

    game_s = fbaH.serialize(game)

    _wb = db.batch()
    _wb.set(db.collection("/games").doc(game.meta.id), game_s, { merge: true })
    await _wb.commit()

    return game



  _get = (id, options = {}) ->
    fba = await fbaI()
    db  = fba.firestore()

    defaults = {}
    defaults.values = [
      'ext-gameofficials'
      'meta-created-at'
      'meta-deleted'
      'meta-id'
      'meta-type'
      'meta-updated-at'
      'meta-v'
      'rel-away-team'
      'rel-division'
      'rel-home-team'
      'rel-league'
      'rel-season'
      'val-location-text'
      'val-score'
      'val-start-clock-time'
      'val-start-timezone'
    ]

    values = defaults.values
    if isObject(options.values)
      ext    = map(values.ext,  (v) -> "ext-#{kebabCase(v)}")
      meta   = map(values.meta, (v) -> "meta-#{kebabCase(v)}")
      rel    = map(values.rel,  (v) -> "rel-#{kebabCase(v)}")
      val    = map(values.val,  (v) -> "val-#{kebabCase(v)}")
      values = intersection(defaults.values, union(ext, meta, rel, val))
    else
      values = defaults.values

    game = await fbaH.get('/games', id, { fields: values })

    return game



  # ---------------------------------------------------------------------------

  return {
    create:  _create
    get:     _get
  }

)()













































