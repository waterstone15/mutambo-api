map = require 'lodash/map'

cartesianProduct = (_as, _bs) ->
  p = []
  p.push([x, y]) for x in _as for y in _bs
  return p
   

flatPaths = (_as, _bs) ->
  pairs = cartesianProduct(_as, _bs)
  return map(pairs, (_p) -> "#{_p[0]}.#{_p[1]}")

module.exports = flatPaths



