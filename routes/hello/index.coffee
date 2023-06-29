# { Logtail } = require('@logtail/node')

module.exports = (ctx) ->
  # logtail = new Logtail(process.env.LOGTAIL_SOURCE_TOKEN)
  # await logtail.info('hello world')
  ctx.ok('Hello World!')
