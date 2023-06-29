FLI      = require '@/local/lib/flame-lib-init'
isEmpty  = require 'lodash/isEmpty'
includes = require 'lodash/includes'
isString = require 'lodash/isString'
set      = require 'lodash/set'
trim     = require 'lodash/trim'


Model = ->
  Flame = await FLI('main')

  fee_types = [ 'player_per_game', 'player_per_season', 'player_per_team', 'team_per_game', 'team_per_season', ]
  price_types = [ 'default', 'early_bird', 'gg_score', 'returning', ]
  prices = {}
  (set(prices, "#{ft}.#{pt}", 0.00) for pt in price_types) for ft in fee_types

  roles = [ 'admin', 'manager', 'player' ]
  fields = [ 'address', 'birthday', 'email', 'full_name', 'gender', 'display_name', 'phone' ]
  info = {}
  (set(info, "#{r}.#{f}", includes([ 'email', 'display_name' ], f)) for f in fields) for r in roles

  M = Flame.model('SeasonSettings', {
    data:
      meta:
        v: '00000.00000.00000'
      rel:
        season: null
      val:
        currency: 'usd'
        prices: prices
        required_info: info
        registration_status:
          player_game:   'closed'
          player_season: 'closed'
          player_team:   'closed'
          team_game:     'closed'
          team_season:   'closed'
        registration_schedule:
          player_game:   {}
          player_season: {}
          player_team:   {}
          team_game:     {}
          team_season:   {}
        roster_rules: {}
        team_limits:
          rostered_players: 1
          team_managers: 1
          team_players: 1
    validators:
      rel:
        season: (_v) -> isString(_v) && !isEmpty(trim(_v))
      val:
        currency:            (_v) -> _v == 'usd'
        prices:              (_v) -> true
        required_info:       (_v) -> true
        registration_status: (_v) -> true
        roster_rules:        (_v) -> true
        team_limits:         (_v) -> true
  })

  return M


module.exports = Model
