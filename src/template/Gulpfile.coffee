# ------------------------------------------------------------------------------
# Load in modules
# ------------------------------------------------------------------------------
gulp = require 'gulp'
$ = require('gulp-load-plugins')()

runSequence = require 'run-sequence'
path = require 'path'
fs = require 'fs'
_ = require 'underscore'

ENV = process.env.NODE_ENV or 'development'
{config} = require 'bedrock-utils'
config.initialize 'config/*.json', debug: true

# ------------------------------------------------------------------------------
# Custom vars and methods
# ------------------------------------------------------------------------------
alertError = $.notify.onError (error) ->
  message = error?.message or error?.toString() or 'Something went wrong'
  "Error: #{ message }"

# ------------------------------------------------------------------------------
# Directory management
# ------------------------------------------------------------------------------
gulp.task 'clean', ->
  dir = config.client.build.root
  fs.mkdirSync dir unless fs.existsSync dir

  gulp.src("#{ dir }/*", read: false)
    .pipe($.plumber errorHandler: alertError)
    .pipe $.rimraf force: true

# ------------------------------------------------------------------------------
# Copy static assets
# ------------------------------------------------------------------------------
gulp.task 'public', ->
  gulp.src("#{ config.client.src.public }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.root)
    .pipe gulp.dest config.client.build.root

gulp.task 'bower', ->
  gulp.src(require('main-bower-files')())
    .pipe($.filter '!**/*.scss')
    .pipe($.plumber errorHandler: alertError)
    .pipe gulp.dest config.client.build.assets

gulp.task 'rename bower css', ->
  gulp.src("bower_components/**/*.css")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.rename prefix: '_', extname: '.scss')
    .pipe(gulp.dest 'bower_components')

# ------------------------------------------------------------------------------
# Compile assets
# ------------------------------------------------------------------------------
gulp.task 'scripts', ->
  coffeeFilter = $.filter '**/*.coffee'
  hamlcFilter = $.filter '**/*.hamlc'

  gulp.src("#{ config.client.src.scripts }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.assets)
    .pipe($.preprocess context: ENV: ENV)
    .pipe(coffeeFilter)
    .pipe($.coffeelint optFile: './.coffeelintrc')
    .pipe($.coffeelint.reporter())
    .pipe($.cond config.client.scripts.map, gulp.dest config.client.build.assets)
    .pipe($.coffee bare: true, sourceMap: config.client.scripts.map)
    .pipe(coffeeFilter.restore())
    .pipe(hamlcFilter)
    .pipe($.hamlCoffee js: true, placement: 'amd')
    .pipe(hamlcFilter.restore())
    .pipe(gulp.dest config.client.build.assets)

gulp.task 'sass', ['public', 'bower', 'images'], ->
  gulp.src("#{ config.client.src.styles }/main.scss")
    .pipe($.sass
      onError: alertError
      includePaths: require('node-bourbon').with(
        config.client.build.root,
        'bower_components'
      )
      imagePath: config.client.sass.imagePath
      sourceMap: config.client.sass.sourceMap
    )
    .pipe(gulp.dest config.client.build.assets)

gulp.task 'images', ->
  gulp.src("#{ config.client.src.images }/**")
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.assets)
    .pipe($.imagemin())
    .pipe(gulp.dest config.client.build.assets)

gulp.task 'html', ->
  hamlcFilter = $.filter '**/*.hamlc'

  gulp.src([
    "#{ config.client.src.html }/**"
    "!#{ config.client.src.html }/**/_*.hamlc"
  ])
    .pipe($.plumber errorHandler: alertError)
    .pipe($.changed config.client.build.root)
    .pipe(hamlcFilter)
    .pipe($.hamlCoffee locals: config)
    .pipe(hamlcFilter.restore())
    .pipe(gulp.dest config.client.build.root)

# ------------------------------------------------------------------------------
# Server
# ------------------------------------------------------------------------------
gulp.task 'server', ->
  nodemon = require 'nodemon'

  nodemon
    script: config.server.main
    watch: config.server.root
    ext: 'js coffee json'

  nodemon
    .on('start', -> console.log 'Server has started')
    .on('quit', -> console.log 'Server has quit')
    .on('restart', (files) -> console.log 'Server restarted due to: ', files)

# ------------------------------------------------------------------------------
# Build
# ------------------------------------------------------------------------------
gulp.task 'build', (cb) ->
  sequence = [
    ['bower', 'scripts', 'public', 'html', 'sass']
    cb
  ]
  runSequence sequence...

# ------------------------------------------------------------------------------
# Watch
# ------------------------------------------------------------------------------
gulp.task 'watch', (cb) ->
  lr = $.livereload config.livereload.port
  gulp.watch("#{ config.client.build.root }/**")
    .on 'change', (file) -> lr.changed file.path

  gulp.watch "#{ config.client.src.scripts }/**", ['scripts']
  gulp.watch "#{ config.client.src.styles }/**/*.scss", ['sass']
  gulp.watch "#{ config.client.src.html }/**/*.hamlc", ['html']
  gulp.watch "#{ config.client.src.images }/**", ['images']
  gulp.watch "#{ config.client.src.public }/**", ['public']

  cb()

# ------------------------------------------------------------------------------
# Default
# ------------------------------------------------------------------------------
gulp.task 'default', ->
  runSequence 'clean', 'build', ['watch', 'server']