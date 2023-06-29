fetch = require 'node-fetch'
log   = require '@/local/lib/log'
qs    = require 'qs'
Vault = require '@/local/lib/arctic-vault'

GS    = require '@/local/models/flame-lib/game-sheet'

module.exports = (ctx) ->

  gid = ctx.params.code

  vault = await Vault.open()
  api2pdf_key = vault.secrets.kv.API2PDF_KEY

  prod = vault.secrets.kv.NODE_ENV
  gs_url = "https://api.mutambo.com/v2/game/sheet/#{gid}/preview"

  try
    opts =
      headers: 
        'Content-Type': 'application/json'
        'Authorization': api2pdf_key
      method: 'POST'
      body: (JSON.stringify {
        url: gs_url
        options:
          width: "8.5in",
          height: "11in",
          marginTop: "0.2in",
          marginBottom: "0.2in",
          marginLeft: "0.2in",
          marginRight: "0.2in",
          pageRanges: "1-10000",
          scale: 0.7,
          omitBackground: false
          delay: 600
      })
    pdf_api_url = "https://v2.api2pdf.com/chrome/pdf/url"
    res = await fetch(pdf_api_url, opts)
    json = await res.json()
  catch e
    log e

  try
    res = await fetch(json.FileUrl)
    buf = await res.buffer()
  catch e
    log e

  (ctx.set 'Content-Type', 'application/pdf')
  ctx.body = buf
  return
