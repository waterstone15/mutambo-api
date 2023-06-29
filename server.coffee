BodyParser = require 'koa-bodyparser'
Cors       = require '@koa/cors'
favicon    = require 'koa-favicon'
Helmet     = require 'koa-helmet'
Koa        = require 'koa'
Logger     = require 'koa-logger'
origins    = require '@/local/middleware/origins'
respond    = require 'koa-respond'
Router     = require 'koa-router'
routes     = require '@/routes'
Vault      = require '@/local/lib/arctic-vault'

app    = new Koa()
router = new Router()

app.use(Helmet())
app.use(Helmet.contentSecurityPolicy({
  directives: { defaultSrc: [ "'none'" ]}
}))
app.use(Logger())
app.use(Cors())
app.use(respond())
app.use(BodyParser({
  jsonLimit: '100mb'
  textLimit: '100mb'
  xmlLimit:  '100mb'
  onerror: (e, ctx) -> ctx.throw(422)
}))
app.use(favicon(__dirname + '/img/favicon.ico'))
routes(router)
app.use(router.routes())
app.use(router.allowedMethods())

module.exports = app
