wait = (delay = 0) ->
  new Promise((resolve) => setTimeout(resolve, delay))

module.exports = wait