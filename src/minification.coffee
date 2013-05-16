path                    = require 'path'
uglify                  = require 'uglify-js'
_                       = require 'underscore'
{ getUrlPath }          = require './util'
{ compilers, stripExt } = require './compilers'

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

module.exports = {
    minify
}
