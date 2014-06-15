derby = require 'derby'
app = module.exports = derby.createApp 'derby-app', __filename
app.serverUse module, 'derby-stylus'

global.app = app

app.loadViews "#{__dirname}/../../views"
app.loadStyles "#{__dirname}/../../styles"

app.get '/', getPage = (page, model)->
  page.render()

