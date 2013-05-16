(function() {
  var compilers, getUrlPath, minify, path, stripExt, uglify, _, _ref;

  path = require('path');

  uglify = require('uglify-js');

  _ = require('underscore');

  getUrlPath = require('./util').getUrlPath;

  _ref = require('./compilers'), compilers = _ref.compilers, stripExt = _ref.stripExt;

  minify = function(js, useropts) {
    var cmpd, inbn, inurl, opts, outbn, outurl, parseopts, sm, smopts, srcmap, stream, streamopts, top;

    if (useropts == null) {
      useropts = {};
    }
    opts = {
      mangle: false,
      srcmap: false,
      outname: '',
      inname: '',
      staticRoot: '',
      staticRootUrl: '/'
    };
    _.extend(opts, useropts);
    parseopts = {};
    if (opts.inname != null) {
      parseopts.filename = opts.inname;
      if ((opts.srcmap != null) && opts.srcmap !== false) {
        inurl = getUrlPath(opts.inname, opts.staticRoot, opts.staticRootUrl);
        outurl = getUrlPath(opts.outname, opts.staticRoot, opts.staticRootUrl);
        inbn = path.basename(inurl);
        outbn = path.basename(outurl);
        parseopts.filename = inurl;
      }
    }
    top = uglify.parse(js, parseopts);
    top.figure_out_scope();
    cmpd = top.transform(uglify.Compressor({
      warnings: false
    }));
    cmpd.figure_out_scope();
    if (opts.mangle) {
      cmpd.mangle_names();
      cmpd.figure_out_scope();
    }
    streamopts = {};
    if (opts.srcmap !== false) {
      smopts = {
        file: "" + (stripExt(outurl)) + ".min.js"
      };
      if (opts.srcmap !== true) {
        smopts.orig = opts.srcmap;
      }
      sm = uglify.SourceMap(smopts);
      streamopts.source_map = sm;
    }
    stream = uglify.OutputStream(streamopts);
    cmpd.print(stream);
    js = stream.toString();
    if ((opts.srcmap != null) && opts.srcmap !== false) {
      srcmap = sm.toString();
      if (_.isString(srcmap)) {
        srcmap = JSON.parse(srcmap);
      }
      if (opts.srcmap === true) {
        srcmap.sources = [inurl];
      }
      return {
        js: js,
        srcmap: srcmap
      };
    }
    return js;
  };

  module.exports = {
    minify: minify
  };

}).call(this);
