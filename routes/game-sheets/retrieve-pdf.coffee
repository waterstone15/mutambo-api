# fbaHelpers   = require '@/local/lib/fba-helpers'
# fbaInit      = require '@/local/lib/fba-init'
# filter       = require 'lodash/filter'
# find         = require 'lodash/find'
# includes     = require 'lodash/includes'
# map          = require 'lodash/map'
# merge        = require 'lodash/merge'
# pick         = require 'lodash/pick'
# puppeteer    = require 'puppeteer'
# puppetInit   = require '@/local/lib/puppeteer-init'
# reverse      = require 'lodash/reverse'
# sortBy       = require 'lodash/sortBy'
# union        = require 'lodash/union'
# unionBy      = require 'lodash/unionBy'
# User         = require '@/local/models/user'
# Vault        = require '@/local/lib/arctic-vault'
# { all }      = require 'rsvp'
# { DateTime } = require 'luxon'
# { hash }     = require 'rsvp'

# module.exports = (ctx) ->

#   { id } = ctx.params

#   [ browser, vault ] = await all([
#     puppeteer.launch({ args: ['--no-sandbox'] })
#     Vault.open()
#   ])

#   page = await browser.newPage()

#   await page.goto("#{vault.secrets.kv.WEB_APP_ORIGIN}/print/roster?id=#{id}")
#   await page.waitForSelector('.print-ready', { timeout: 10000 })

#   pdf = await page.pdf({
#     format: 'Letter'
#     margin: { top: '.25in', right: '.25in', bottom: '.25in', left: '.25in' }
#   })

#   await page.close()
#   await browser.close()

#   ctx.set('Content-Type', 'application/pdf')

#   ctx.body = pdf

#   return
