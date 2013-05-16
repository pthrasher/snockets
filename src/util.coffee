path      = require 'path'
_         = require 'underscore'
SourceMap = require 'source-map'

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

parseDirectives = (code) ->
    code = code.replace /[\r\t ]+$/gm, '\n'    # fix for issue #2
    return [] unless match = HEADER.exec(code)
    header = match[0]
    match[1] while match = DIRECTIVE.exec header

timeEq = (date1, date2) ->
    date1? and date2? and date1.getTime() is date2.getTime()


getUrlPath = (absPath, absStaticRoot, staticRootUrl) ->
    absPath = path.resolve path.normalize absPath
    absStaticRoot = path.resolve path.normalize absStaticRoot

    if absStaticRoot[absStaticRoot.length - 1] isnt '/'
        absStaticRoot += '/'

    if staticRootUrl[staticRootUrl.length - 1] isnt '/'
        staticRootUrl += '/'

    absPath.replace absStaticRoot, staticRootUrl

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

sourceMapCat = (opts) ->
    generated = new SourceMap.SourceMapGenerator({
        # The filename of the generated source (output) that this source
        # map is associated with.
        file: opts.filename
    })

    # Last line of the concatenated script so far
    combinedGeneratedLine = 1

    for _original in opts.maps
        if _original.empty? and _original.empty is true
            combinedGeneratedLine += _original.numLines
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
                    source: mapping.source    # Original source file
                )
            catch e
                throw new Error "Invalid Mapping: #{JSON.stringify mapping}"

            originalLastLine = mapping.generatedLine

        # Add lines of the current map source file to our concatenated file
        combinedGeneratedLine += originalLastLine

    return JSON.parse generated.toString()

module.exports = {
    timeEq
    getUrlPath
    HoldingQueue
    parseDirectives
    sourceMapCat
    EXPLICIT_PATH
    DIRECTIVE
    HEADER
}
