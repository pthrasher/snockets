(function() {
  var CoffeeScript, compilers, getUrlPath, jsExts, path, stripExt, _,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  _ = require('underscore');

  path = require('path');

  CoffeeScript = require('coffee-script');

  getUrlPath = require('./util').getUrlPath;

  jsExts = function() {
    var ext;

    return ((function() {
      var _results;

      _results = [];
      for (ext in compilers) {
        _results.push("." + ext);
      }
      return _results;
    })()).concat('.js');
  };

  stripExt = function(filePath) {
    var _ref;

    if (_ref = path.extname(filePath), __indexOf.call(jsExts(), _ref) >= 0) {
      return filePath.slice(0, filePath.lastIndexOf('.'));
    } else {
      return filePath;
    }
  };

  compilers = {
    coffee: {
      match: /\.js$/,
      compileSync: function(sourcePath, source, useropts) {
        var compileopts, inbn, inname, inurl, js, opts, outbn, outname, output, outurl, srcmap;

        if (useropts == null) {
          useropts = {};
        }
        opts = {
          srcmap: false,
          staticRoot: '',
          staticRootUrl: '/'
        };
        _.extend(opts, useropts);
        compileopts = {
          filename: sourcePath
        };
        if (opts.srcmap) {
          outname = "" + sourcePath + ".js";
          inname = sourcePath;
          inurl = getUrlPath(inname, opts.staticRoot, opts.staticRootUrl);
          outurl = getUrlPath(outname, opts.staticRoot, opts.staticRootUrl);
          inbn = path.basename(inurl);
          outbn = path.basename(outurl);
          _.extend(compileopts, {
            filename: outbn,
            sourceMap: true,
            generatedFile: "" + (stripExt(outurl)) + ".min.js",
            sourceFiles: [inurl]
          });
        }
        output = CoffeeScript.compile(source, compileopts);
        if (opts.srcmap) {
          srcmap = output.v3SourceMap;
          if (_.isString(srcmap)) {
            srcmap = JSON.parse(srcmap);
          }
          js = output.js;
          return {
            js: js,
            srcmap: srcmap
          };
        }
        return output;
      }
    }
  };

  module.exports = {
    jsExts: jsExts,
    compilers: compilers,
    stripExt: stripExt
  };

}).call(this);
