# vim:expandtab ts=2 sw=2
# [snockets](http://github.com/TrevorBurnham/snockets)

DepGraph = require 'dep-graph'
SourceMap = require 'source-map'

CoffeeScript = require 'coffee-script'
fs           = require 'fs'
path         = require 'path'
uglify       = require 'uglify-js'
_            = require 'underscore'

module.exports = class Snockets
  constructor: (@options = {}) ->
    @options.srcmap ?= false
    @options.target ?= null
    @options.staticRoot ?= null
    @options.staticRootUrl ?= '/'
    @options.src ?= '.'
    @options.async ?= true
    @cache = {}
    @concatCache = {}
    @depGraph = new DepGraph
    @logLevels = [
      'info'
      'warn'
      'debug'
      'error'
    ]

    # If the user wants srcmaps, we need to know a few other things first in
    # order to adequately fill out info within them. If this info isn't
    # provided, we cannot proceed.
    if @options.srcmap
      unless @options.staticRoot? or @options.target?
        if not @options.staticRoot? and not @options.target?
          errorStr = 'both of the options \'staticRoot\' and \'target\''
        else if @options.staticRoot? and not @options.target?
          errorStr = '\'target\' option'
        else if not @options.staticRoot? and @options.target?
          errorStr = '\'staticRoot\' option'
        throw new Error("When generating source maps
                         #{errorStr} must be provided.")

  # ## Logging methods
  log: (args, level) ->
    if _.contains(@logLevels, level)
      console.log.apply console, args

  info: (args...) => @log args, 'info'
  warn: (args...) => @log args, 'warn'
  debug: (args...) => @log args, 'debug'
  error: (args...) => @log args, 'error'

  # ## Public methods

  scan: (filePath, flags, callback) ->
    if typeof flags is 'function'
      callback = flags; flags = {}
    flags ?= {}
    flags.async ?= @options.async

    @updateDirectives filePath, flags, (err, graphChanged) =>
      if err
        if callback then return callback err else throw err
      callback? null, @depGraph, graphChanged
      @depGraph

  getCompiledChain: (filePath, flags, callback) ->
    if typeof flags is 'function'
      callback = flags; flags = {}
    flags ?= {}
    flags.async ?= @options.async

    @updateDirectives filePath, flags, (err, graphChanged) =>
      if err
        if callback then return callback err else throw err
      try
        chain = @depGraph.getChain filePath
      catch e
        if callback then return callback e else throw e

      compiledChain = for link in chain.concat filePath
        o = {}
        if @compileFile link
          o.filename = stripExt(link) + '.js'
        else
          o.filename = link
        o.js = @cache[link].js.toString 'utf8'
        o

      callback? null, compiledChain, graphChanged
      compiledChain

  getConcatenation: (filePath, flags, callback) ->
    if typeof flags is 'function'
      callback = flags; flags = {}
    flags ?= {}
    flags.async ?= @options.async
    concatenationChanged = true

    @updateDirectives filePath, flags, (err, graphChanged) =>
      # fail fast
      if err
        if callback then return callback err else throw err

      doSrcMap = @options.srcmap
      doMinify = flags.minify
      # if doSrcMap and not doMinify
      #   # we can't do srcmaps without minification reliably.
      #   # TODO: We *can* do this if every src in the chain is coffeescript, or
      #   #       another transpiled language that supports source maps. However,
      #   #       if some of the source is javascript, or the language doesn't
      #   #       support generating source maps, we cannot reliably create
      #   #       concatenated files that map properly. Or any source maps in the
      #   #       chain are missing, we don't have a simple way of doing this.
      #   doSrcMap = false
      #   @warn "Disabling srcmap generation due to no minification. [#{filePath}]"


      # create the placeholder if it doesn't exist already.
      unless @concatCache[filePath]?
        @concatCache[filePath] = {}

      # Don't trust the cache
      cacheValid = false
      hasData    = @concatCache[filePath].data?
      hasMinData = @concatCache[filePath].minifiedData?
      hasSrcMap  = @concatCache[filePath].srcmap?

      # Attempt to validate the cache.
      if not (doSrcMap and doMinify) # not srcmapping, not minifying
        cacheValid = true if hasData
      if not doSrcMap and doMinify # not srcmapping, minifying
        cacheValid = true if hasMinData
      if doSrcMap and doMinify # we're srcmapping and minifying
        cacheValid = true if hasSrcMap and hasMinData

      # We should now have a rough, early overview as to whether or not the
      # cache is valid, as well as what sorts of things need to be generated
      # below.

      try
        if cacheValid and not doMinify
          # We have a valid cache, and we're not minifying.
          concatenation = @concatCache[filePath].data.toString 'utf8'
          concatenationChanged = false
        else if cacheValid and doMinify and not doSrcMap
          concatenation = @concatCache[filePath].minifiedData.toString 'utf8'
          concatenationChanged = false
        else if cacheValid and doMinify and doSrcMap
          js = @concatCache[filePath].minifiedData.toString 'utf8'
          srcmap = @concatCache[filePath].srcmap
          concatenation = {
            js
            srcmap
          }
          concatenationChanged = false
        else
          @concatCache[filePath].maps = {}

          # append the src file to the end of it's own dependency list.
          chain = @depGraph.getChain(filePath).concat filePath

          cacheMiss = false # keep track of whether or not anything was regenerated.

          sources = []
          for link in chain
            console.log "compiling #{link}"
            isCompiled = @compileFile link
            console.log "compiled #{link}"

            cached = @cache[link] # get a reference to the cache.

            # TODO: Find out what could possibly cause a file to not be cached
            #       at this point..
            continue unless cached?

            _hasJs      = cached.js?
            _hasMinData = cached.minifiedData?
            _hasSrcMap  = cached.srcmap?

            _cacheValid = false
            if not doMinify
              _cacheValid = if _hasJs then true else false
            if not doSrcMap and doMinify # not srcmapping, minifying
              _cacheValid = if _hasMinData then true else false
            if doSrcMap and not doMinify # we're srcmapping and not minifying
              _cacheValid = if _hasSrcMap and _hasJs then true else false
            if doSrcMap and doMinify # we're srcmapping and minifying
              _cacheValid = if _hasSrcMap and _hasMinData then true else false

            if _cacheValid and not doMinify and not doSrcMap
              sources.push cached.js.toString 'utf8'
            else if _cacheValid and doMinify and not doSrcMap
              sources.push cached.minifiedData.toString 'utf8'
            else if _cacheValid and doMinify and doSrcMap
              sources.push {
                js: cached.minifiedData.toString 'utf8'
                srcmap: cached.srcmap
              }
            else if _cacheValid and not doMinify and doSrcMap
              js = cached.js.toString 'utf8'
              unless cached.srcmap?
                numLines = js.split(/\r\n|\r|\n/gm).length
                cached.srcmap =
                    empty: true
                    numLines: numLines
                    file: link

              sources.push {
                js: js
                srcmap: cached.srcmap
              }
            else
              # CACHE MISS
              # Do minification / sourcemapping
              cacheMiss = true
              _srcmap = null
              _mindata = null

              minopts = {}
              if doSrcMap
                absLink = path.resolve @options.src, link
                minopts.outname = "#{stripExt(absLink)}.js"
                minopts.srcmap = true
                minopts.inname = absLink
                minopts.staticRoot = @options.staticRoot
                minopts.staticRootUrl = @options.staticRootUrl

              if isCompiled and _hasSrcMap and doSrcMap
                # pass existing srcmap to minifier.
                minopts.srcmap = cached.srcmap

              console.log "getting js for #{link}"
              toMinify = cached.js.toString 'utf8'
              console.log "got js for #{link}"

              if doMinify
                result = minify toMinify, minopts
              else
                if doSrcMap
                  if isCompiled
                    result =
                      srcmap: cached.srcmap
                      js: toMinify
                  else
                    numLines = toMinify.split(/\r\n|\r|\n/gm).length
                    result =
                      srcmap:
                        empty: true
                        numLines: numLines
                        file: link
                      js: toMinify
                else
                  result = toMinify

              if doSrcMap
                _srcmap = result.srcmap
                _mindata = new Buffer result.js
                sources.push {
                  srcmap: _srcmap
                  js: result.js
                }
              else
                _mindata = new Buffer result
                sources.push result


              cached.minifiedData = _mindata
              cached.srcmap = _srcmap


          console.log 'done with chain'
          if cacheMiss
            concatenationChanged = true
          else
            concatenationChanged = false

          # Concatenate the aggregated sources
          if not doSrcMap
            concatenation = sources.join '\n'
          else
            # We have to concatenate the source maps alongside the sources
            _sources = _.pluck sources, 'js'
            _maps    = _.pluck sources, 'srcmap'

            catjs = _sources.join '\n'
            targetUrl = getUrlPath @options.target, @options.staticRoot, @options.staticRootUrl
            catmaps = sourceMapCat
              filename: targetUrl
              maps: _maps

            concatenation =
              js: catjs
              srcmap: catmaps
      catch e
        if callback then return callback e else throw e

      if not (doMinify and doSrcMap)
        @concatCache[filePath].data = new Buffer concatenation
      else if doMinify and not doSrcMap
        @concatCache[filePath].minifiedData = new Buffer concatenation
      else if doMinify and doSrcMap
        @concatCache[filePath].minifiedData = new Buffer concatenation.js
        @concatCache[filePath].srcmap = concatenation.srcmap
      else if not doMinify and doSrcMap
        @concatCache[filePath].data = new Buffer concatenation.js
        @concatCache[filePath].srcmap = concatenation.srcmap

      callback? null, concatenation, concatenationChanged
      concatenation

  # ## Internal methods

  # Interprets the directives from the given file to update `@depGraph`.
  updateDirectives: (filePath, flags, excludes..., callback) ->
    return callback() if filePath in excludes
    excludes.push filePath

    depList = []
    graphChanged = false
    q = new HoldingQueue
      task: (depPath, next) =>
        return next() unless path.extname(depPath) in jsExts()
        if depPath is filePath
          err = new Error("Script tries to require itself: #{filePath}")
          return callback err
        unless depPath in depList
          depList.push depPath
        @updateDirectives depPath, flags, excludes..., (err, depChanged) ->
          return callback err if err
          graphChanged or= depChanged
          next()
      onComplete: =>
        unless _.isEqual depList , @depGraph.map[filePath]
          @depGraph.map[filePath] = depList
          graphChanged = true
        if graphChanged
          @concatCache[filePath] = null
        callback null, graphChanged

    require = (relPath) =>
      q.waitFor relName = stripExt relPath
      if relName.match EXPLICIT_PATH
        depPath = relName + '.js'
        q.perform relName, depPath
      else
        depName = @joinPath path.dirname(filePath), relName
        @findMatchingFile depName, flags, (err, depPath) ->
          return callback err if err
          q.perform relName, depPath

    requireTree = (dirName) =>
      q.waitFor dirName
      @readdir @absPath(dirName), flags, (err, items) =>
        return callback err if err
        q.unwaitFor dirName
        for item in items
          itemPath = @joinPath dirName, item
          continue if @absPath(itemPath) is @absPath(filePath)
          q.waitFor itemPath
          do (itemPath) =>
            @stat @absPath(itemPath), flags, (err, stats) =>
              return callback err if err
              if stats.isFile()
                q.perform itemPath, itemPath
              else
                requireTree itemPath
                q.unwaitFor itemPath

    @readFile filePath, flags, (err, fileChanged) =>
      return callback err if err
      if fileChanged then graphChanged = true
      for directive in parseDirectives(@cache[filePath].data.toString 'utf8')
        words = directive.replace(/['"]/g, '').split /\s+/
        [command, relPaths...] = words

        switch command
          when 'require'
            require relPath for relPath in relPaths
          when 'require_tree'
            for relPath in relPaths
              requireTree @joinPath path.dirname(filePath), relPath

      q.finalize()

  # Searches for a file with the given name (no extension, e.g. `'foo/bar'`)
  findMatchingFile: (filename, flags, callback) ->
    tryFiles = (filePaths) =>
      for filePath in filePaths
        if stripExt(@absPath filePath) is @absPath(filename)
          callback null, filePath
          return true

    return if tryFiles _.keys @cache
    @readdir path.dirname(@absPath filename), flags, (err, files) =>
      return callback err if err
      return if tryFiles (for file in files
        @joinPath path.dirname(filename), file
      )
      callback new Error("File not found: '#{filename}'")

  # Wrapper around fs.readdir or fs.readdirSync, depending on flags.async.
  readdir: (dir, flags, callback) ->
    if flags.async
      fs.readdir @absPath(dir), callback
    else
      try
        files = fs.readdirSync @absPath(dir)
        callback null, files
      catch e
        callback e

  # Wrapper around fs.stat or fs.statSync, depending on flags.async.
  stat: (filePath, flags, callback) ->
    if flags.async
      fs.stat @absPath(filePath), callback
    else
      try
        stats = fs.statSync @absPath(filePath)
        callback null, stats
      catch e
        callback e

  # Reads a file's data and timestamp into the cache.
  readFile: (filePath, flags, callback) ->
    @stat filePath, flags, (err, stats) =>
      return callback err if err
      if timeEq @cache[filePath]?.mtime, stats.mtime
        return callback null, false
      if flags.async
          fs.readFile @absPath(filePath), (err, data) =>
            return callback err if err
            @cache[filePath] = {mtime: stats.mtime, data}
            callback null, true
      else
        try
          data = fs.readFileSync @absPath(filePath)
          @cache[filePath] = {mtime: stats.mtime, data}
          callback null, true
        catch e
          callback e

  compileFile: (filePath) ->
    if (ext = path.extname filePath) is '.js'
      @cache[filePath].js = @cache[filePath].data
      return false
    else
      src = @cache[filePath].data.toString 'utf8'
      pth = @absPath(filePath)
      js = compilers[ext[1..]].compileSync @absPath(filePath), src, @options
      unless _.isString js
        @cache[filePath].srcmap = js.srcmap
        js = js.js
      @cache[filePath].js = new Buffer(js)
      return true

  absPath: (relPath) ->
    if relPath.match EXPLICIT_PATH
      relPath
    else if @options.src.match EXPLICIT_PATH
      @joinPath @options.src, relPath
    else
      @joinPath process.cwd(), @options.src, relPath

  joinPath: ->
    filePath = path.join.apply path, arguments

    # Replace backslashes with forward slashes for Windows compatability
    if process.platform is 'win32'
      slash = '/' # / on the same line as the regex breaks ST2 syntax highlight
      filePath.replace /\\/g, slash
    else
      filePath

# ## Compilers

module.exports.compilers = compilers =
  coffee:
    match: /\.js$/
    compileSync: (sourcePath, source, useropts = {}) ->
      opts =
        srcmap: false
        staticRoot: ''
        staticRootUrl: '/'
      _.extend opts, useropts

      compileopts =
        filename: sourcePath

      if opts.srcmap
        outname = "#{sourcePath}.js"
        inname = sourcePath

        inurl = getUrlPath inname, opts.staticRoot, opts.staticRootUrl
        outurl = getUrlPath outname, opts.staticRoot, opts.staticRootUrl
        inbn = path.basename inurl
        outbn = path.basename outurl

        _.extend compileopts,
          filename: outbn
          sourceMap: true
          generatedFile: "#{stripExt outurl}.min.js"
          sourceFiles: [inurl]


      output = CoffeeScript.compile source, compileopts
      if opts.srcmap
        srcmap = output.v3SourceMap
        if _.isString srcmap
          srcmap = JSON.parse srcmap
        js = output.js
        return { js, srcmap }
      output

# ## Regexes

EXPLICIT_PATH = /^\/|:/

HEADER = ///
(?:
  (\#\#\# .* \#\#\#\n*) |
  (// .* \n*) |
  (\# .* \n*)
)+
///

DIRECTIVE = ///
^[\W] *= \s* (\w+.*?) (\*\\/)?$
///gm

# ## Utility functions

class HoldingQueue
  constructor: ({@task, @onComplete}) ->
    @holdKeys = []
  waitFor: (key) ->
    @holdKeys.push key
  unwaitFor: (key) ->
    @holdKeys = _.without @holdKeys, key
  perform: (key, args...) ->
    @task args..., => @unwaitFor key
  finalize: ->
    if @holdKeys.length is 0
      @onComplete()
    else
      h = setInterval (=>
        if @holdKeys.length is 0
          @onComplete()
          clearInterval h
      ), 10

parseDirectives = (code) ->
  code = code.replace /[\r\t ]+$/gm, '\n'  # fix for issue #2
  return [] unless match = HEADER.exec(code)
  header = match[0]
  match[1] while match = DIRECTIVE.exec header

stripExt = (filePath) ->
  if path.extname(filePath) in jsExts()
    filePath[0...filePath.lastIndexOf('.')]
  else
    filePath

jsExts = ->
  (".#{ext}" for ext of compilers).concat '.js'


minify = (js, useropts = {}) ->
  opts =
    mangle: false
    srcmap: false
    outname: ''
    inname: ''
    staticRoot: ''
    staticRootUrl: '/'

  _.extend opts, useropts

  parseopts = {}

  if opts.inname?
    parseopts.filename = opts.inname
    if opts.srcmap? and opts.srcmap isnt false

      inurl = getUrlPath opts.inname, opts.staticRoot, opts.staticRootUrl
      outurl = getUrlPath opts.outname, opts.staticRoot, opts.staticRootUrl
      inbn = path.basename inurl
      outbn = path.basename outurl

      parseopts.filename = inurl

  top = uglify.parse js, parseopts
  top.figure_out_scope()

  # cmpd == compressed
  cmpd = top.transform uglify.Compressor
    warnings: false
  cmpd.figure_out_scope()

  if opts.mangle
    cmpd.mangle_names()
    cmpd.figure_out_scope()

  streamopts = {}
  if opts.srcmap isnt false

    
    smopts =
      file: "#{stripExt(outurl)}.min.js"

    if opts.srcmap isnt true
      # setting srcmap to true just makes us create an srcmap, otherwise, we're
      # passing one in from another compiler.
      smopts.orig = opts.srcmap

    sm = uglify.SourceMap smopts
    streamopts.source_map = sm

  stream = uglify.OutputStream streamopts
  cmpd.print stream

  js = stream.toString()
  if opts.srcmap? and opts.srcmap isnt false
    srcmap = sm.toString()
    if _.isString srcmap
      srcmap = JSON.parse srcmap
    # TODO: Look into uglify's source to figure out the correct way to get
    # uglify to set this for non-compiled scripts
    if opts.srcmap is true # Just a standard js file to be minified.
      srcmap.sources = [inurl]
    return { js, srcmap }

  js


getUrlPath = (absPath, absStaticRoot, staticRootUrl) ->
  absPath = path.resolve path.normalize absPath
  absStaticRoot = path.resolve path.normalize absStaticRoot

  if absStaticRoot[absStaticRoot.length - 1] isnt '/'
    absStaticRoot += '/'

  if staticRootUrl[staticRootUrl.length - 1] isnt '/'
    staticRootUrl += '/'

  absPath.replace absStaticRoot, staticRootUrl


sourceMapCat = (opts) ->
  generated = new SourceMap.SourceMapGenerator({
    # The filename of the generated source (output) that this source
    # map is associated with.
    file: opts.filename
  })

  # Last line of the concatenated script so far
  combinedGeneratedLine = 1

  for _original in opts.maps
    console.log "processing map for #{_original.file}"
    if _original.empty? and _original.empty is true
      console.log "empty map found for #{opts.filename}"
      combinedGeneratedLine += _original.numLines
      console.log "#{_original.file} ends on line #{combinedGeneratedLine}"
      continue

    original = new SourceMap.SourceMapConsumer _original
    # Last line of the current map source when eachMapping finishes
    originalLastLine = null

    original.eachMapping (mapping) ->
      try
        generated.addMapping(
          generated:
            line: combinedGeneratedLine + mapping.generatedLine
            column: mapping.generatedColumn
          original:
            line: mapping.originalLine
            column: mapping.originalColumn
          source: mapping.source  # Original source file
        )
      catch e
        throw new Error "Invalid Mapping: #{JSON.stringify mapping}"

      originalLastLine = mapping.generatedLine

    # Add lines of the current map source file to our concatenated file
    combinedGeneratedLine += originalLastLine

  return JSON.parse generated.toString()

timeEq = (date1, date2) ->
  date1? and date2? and date1.getTime() is date2.getTime()
