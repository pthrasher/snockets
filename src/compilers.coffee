_              = require 'underscore'
path           = require 'path'
CoffeeScript   = require 'coffee-script'
{ getUrlPath } = require './util'

jsExts = ->
    (".#{ext}" for ext of compilers).concat '.js'

stripExt = (filePath) ->
    if path.extname(filePath) in jsExts()
        filePath[0...filePath.lastIndexOf('.')]
    else
        filePath

compilers =
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

module.exports = {
    jsExts
    compilers
    stripExt
}
