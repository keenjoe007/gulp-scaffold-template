browserify   = require 'browserify'
browserSync  = require 'browser-sync'
chalk        = require 'chalk'
CSSmin       = require 'gulp-minify-css'
ecstatic     = require 'ecstatic'
filter       = require 'gulp-filter'
gulp         = require 'gulp'
gutil        = require 'gulp-util'
jade         = require 'gulp-jade'
path         = require 'path'
prefix       = require 'gulp-autoprefixer'
prettyTime   = require 'pretty-hrtime'
source       = require 'vinyl-source-stream'
sourcemaps   = require 'gulp-sourcemaps'
streamify    = require 'gulp-streamify'
stylus       = require 'gulp-stylus'
uglify       = require 'gulp-uglify'
watchify     = require 'watchify'
MockServer = require('easymock').MockServer
url = require('url')
proxy = require('proxy-middleware')

production   = process.env.NODE_ENV is 'production'

config =
  scripts:
    source: './src/coffee/main.coffee'
    extensions: ['.coffee']
    destination: './public/js/'
    filename: 'bundle.js'
  templates:
    source: './src/jade/*.jade'
    watch: './src/jade/*.jade'
    destination: './public/'
  styles:
    source: './src/stylus/style.styl'
    watch: './src/stylus/*.styl'
    destination: './public/css/'
  assets:
    source: './src/assets/**/*.*'
    watch: './src/assets/**/*.*'
    destination: './public/'

handleError = (err) ->
  gutil.log err
  gutil.beep()
  this.emit 'end'

gulp.task 'scripts', ->

  bundle = browserify
    entries: [config.scripts.source]
    extensions: config.scripts.extensions
    debug: not production

  build = bundle.bundle()
    .on 'error', handleError
    .pipe source config.scripts.filename

  build.pipe(streamify(uglify())) if production

  build
    .pipe gulp.dest config.scripts.destination

gulp.task 'templates', ->
  pipeline = gulp
    .src config.templates.source
    .pipe(jade(pretty: not production))
    .on 'error', handleError
    .pipe gulp.dest config.templates.destination

  pipeline = pipeline.pipe browserSync.reload(stream: true) unless production

  pipeline

gulp.task 'styles', ->
  styles = gulp.src config.styles.source
  styles = styles.pipe(sourcemaps.init()) unless production
  styles = styles.pipe stylus
      'include css': true

    .on 'error', handleError
    .pipe prefix 'last 2 versions', 'Chrome 34', 'Firefox 28', 'iOS 7'

  styles = styles.pipe(CSSmin()) if production
  styles = styles.pipe(sourcemaps.write '.') unless production
  styles = styles.pipe gulp.dest config.styles.destination

  unless production
    styles = styles
      .pipe filter '**/*.css'
      .pipe browserSync.reload(stream: true)

  styles

gulp.task 'assets', ->
  gulp
    .src config.assets.source
    .pipe gulp.dest config.assets.destination

gulp.task 'easymock', ()->
  options = 
    keepalive: true
    port: 4444
    path: './api'
  server = new MockServer(options)
  server.start()

gulp.task 'server', ['easymock'], ->
  proxyOptions = url.parse('http://localhost:4444/')
  proxyOptions.route = '/api'
  browserSync
    port:      9001
    server:
      baseDir: './public'
      middleware: [proxy(proxyOptions)]

gulp.task 'watch', ->
  gulp.watch config.templates.watch, ['templates']
  gulp.watch config.styles.watch, ['styles']
  gulp.watch config.assets.watch, ['assets']

  bundle = watchify browserify
    entries: [config.scripts.source]
    extensions: config.scripts.extensions
    debug: not production
    cache: {}
    packageCache: {}
    fullPaths: true

  bundle.on 'update', ->
    gutil.log "Starting '#{chalk.cyan 'rebundle'}'..."
    start = process.hrtime()
    build = bundle.bundle()
      .on 'error', handleError
      .pipe source config.scripts.filename

    build
      .pipe gulp.dest config.scripts.destination
      .pipe(browserSync.reload(stream: true))

    gutil.log "Finished '#{chalk.cyan 'rebundle'}' after #{chalk.magenta prettyTime process.hrtime start}"

  .emit 'update'

gulp.task 'no-js', ['templates', 'styles', 'assets']
gulp.task 'build', ['scripts', 'no-js']
# scripts and watch conflict and will produce invalid js upon first run
# which is why the no-js task exists.
gulp.task 'default', ['watch', 'no-js', 'server']
