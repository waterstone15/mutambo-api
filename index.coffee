alias = require('module-alias')
alias.addAlias('@', __dirname)

require('dotenv').config() if !process.env.PORT

port = process.env.PORT || 3242

server = require('@/server')
server.listen(port, -> console.log("\nAPI running: http://localhost:#{port}"))
