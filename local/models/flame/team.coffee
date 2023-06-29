Flame      = require '@/local/lib/flame'
isEmpty    = require 'lodash/isEmpty'
isString   = require 'lodash/isString'
isInteger  = require 'lodash/isInteger'

Model = (->

  _Model = Flame.extend({
    obj:
      meta:
        type: 'team'
        v: 100
      val:
        manager_count: 0
        name: null
        notes: null
        player_count: 0
      rel:
        division: null
        league: null
        league_team_player_invite_link: null
        manager_invite_link: null
        payment: null
        player_invite_link: null
        registration: null
        season: null
    ok:
      val:
        manager_count: (v) -> isInteger(v) && (v >= 0)
        name:          (v) -> !isEmpty(v) && isString(v)
        notes:         (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        player_count:  (v) -> isInteger(v) && (v >= 0)
      rel:
        division:                       (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        league:                         (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        league_team_player_invite_link: (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        manager_invite_link:            (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        payment:                        (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        player_invite_link:             (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        registration:                   (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
        season:                         (v) -> isEmpty(v) || (!isEmpty(v) && isString(v))
  })

  return _Model

)()
module.exports = Model
