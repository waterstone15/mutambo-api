User = require '@/local/models/user'

module.exports = (ctx) ->
  { uid } = ctx.state.fbUser
  user = await User.getByUid(uid)
  ctx.ok({ user })