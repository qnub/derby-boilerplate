# 4-ый экспресс
express = require 'express'

# В 4-ом экспрессе все middleware вынесены в отдельные модули
# приходится каждый из них подключать по отдельности
session = require 'express-session'

# Serve static files
serveStatic = require 'serve-static'

# Compression middleware
compression = require 'compression'

# favicon serving middleware
favicon = require 'serve-favicon'

# Подключаем store
connectStore = null
sessionStore = null

if process.env.REDIS_HOST
    redis = require 'redis'

    redisClient;
    redisClient = redis.createClient process.env.REDIS_PORT, process.env.REDIS_HOST
    if process.env.REDIS_PASSWORD
        redisClient.auth process.env.REDIS_PASSWORD

    connectStore = require('connect-redis')(session);
    sessionStore = new connectStore
        host: process.env.REDIS_HOST
        port: process.env.REDIS_PORT
        pass: process.env.REDIS_PASSWORD
else
    connectStore = require('connect-mongo')(session);
    sessionStore = new connectStore
        url: process.env.MONGO_URL

# Обработчик ошибок - я вынес его в отдельную папочку,
# чтобы не отвекал
midError = require './error'

derby = require 'derby'

# BrowserChannel - аналог socket.io от Гугла - транспорт, используемый
# дерби, для передачи данных из браузеров на сервер

# liveDbMongo - драйвер монги для дерби - умеет реактивно обновлять данные
racerBrowserChannel = require 'racer-browserchannel'
liveDbMongo = require 'livedb-mongo'

# Для любителей coffee
coffeeify = require 'coffeeify'

# Подключаем механизм создания бандлов browserify
derby.use(require('racer-bundle'))

exports.setup = (app, options, cb)->

    # Инициализируем подкючение к БД (здесь же обычно подключается еще и redis)
    store = derby.createStore
        db: liveDbMongo "#{process.env.MONGO_URL}?auto_reconnect", {safe: true}
        redis: redisClient

    publicDir = options.static or "#{__dirname}/../../public"

    # Здесь приложение отдает свой "бандл"
    # (т.е. здесь обрабатываются запросы к /derby/...)
    store.on 'bundle', (browserify)->
        # Add support for directly requiring coffeescript in browserify bundles
        browserify.transform {global: true}, coffeeify

        # HACK: In order to use non-complied coffee node modules, we register it
        # as a global transform. However, the coffeeify transform needs to happen
        # before the include-globals transform that browserify hard adds as the
        # first trasform. This moves the first transform to the end as a total
        # hack to get around this
        pack = browserify.pack

        browserify.pack = (opts)->
            detectTransform = opts.globalTransform.shift()
            opts.globalTransform.push detectTransform
            pack.apply this, arguments

    expressApp = express()
        .use(favicon("#{publicDir}/images/favicon.ico"))
        .use(compression())

    if publicDir
        if Array.isArray publicDir
            for o in publicDir
                expressApp.use o.route, serveStatic(o.dir)
        else
            expressApp.use serveStatic(publicDir)

    # Здесь в бандл добавляется клиетский скрипт browserchannel,
    # и возвращается middleware обрабатывающее клиентские сообщения
    # (browserchannel основан на longpooling - т.е. здесь обрабатываются
    # запросы по адресу /channel)
    expressApp.use racerBrowserChannel(store)

    # В req добавляется метод getModel, позволяющий обычным
    # express-овским котроллерам читать и писать в БД см. createUserId
    expressApp.use store.modelMiddleware()

    expressApp.use require('cookie-parser')(process.env.SESSION_COOKIE)
    expressApp.use session(
        secret: process.env.SESSION_SECRET,
        store: sessionStore
    )

    expressApp.use createUserId

    # Здесь регистрируем контроллеры дерби-приложения,
    # они будут срабатывать, когда пользователь будет брать страницы с сервера
    expressApp.use(app.router());

    # Если бы у на были обычные экспрессовские роуты - мы бы положили их СЮДА

    # Маршрут по умолчанию - генерируем 404 ошибку
    expressApp.all '*', (req, res, next)->
        next "404: #{req.url}"


    # Обработчик ошибок
    expressApp.use midError()

    app.writeScripts store, publicDir, {extensions: ['.coffee']}, (err)->
        cb err, expressApp


# Пробрасываем id-юзера из сессии в модель дерби,
# если в сессии id нет - генерим случайное
createUserId = (req, res, next) ->
    model = req.getModel()
    userId = req.session.userId

    if not userId
        userId = req.session.userId = model.id()

    model.set '_session.userId', userId
    next()


