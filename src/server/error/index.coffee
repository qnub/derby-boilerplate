derby = require 'derby'

module.exports = ->
    errorApp = derby.createApp()
    errorApp.loadViews "#{__dirname}/views/error"
    errorApp.loadStyles "#{__dirname}/styles/reset"
    errorApp.loadStyles "#{__dirname}/styles/error"

    (err, req, res, next)->
        console.log 'error'
        if not err
            return next()

        message = err.message or err.toString()
        status = parseInt message
        status = if ((status >= 400) and (status < 600)) then status else 500

        if status < 500
            console.log err.message or err
        else
            console.log err.stack or err

        page = errorApp.createPage req, res, next
        page.renderStatic status, status.toString()
