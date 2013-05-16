(function() {
  var DIRECTIVE, DepGraph, EXPLICIT_PATH, HEADER, HoldingQueue, Snockets, SourceMap, compilers, fs, getUrlPath, jsExts, minify, parseDirectives, path, sourceMapCat, stripExt, timeEq, _, _ref, _ref1,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  DepGraph = require('dep-graph');

  SourceMap = require('source-map');

  fs = require('fs');

  path = require('path');

  _ = require('underscore');

  minify = require('./minification').minify;

  _ref = require('./util'), timeEq = _ref.timeEq, getUrlPath = _ref.getUrlPath;

  _ref1 = require('./compilers'), compilers = _ref1.compilers, jsExts = _ref1.jsExts, stripExt = _ref1.stripExt;

  module.exports = Snockets = (function() {
    function Snockets(options) {
      var errorStr, _base, _base1, _base2, _base3, _base4, _base5, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;

      this.options = options != null ? options : {};
      this.error = __bind(this.error, this);
      this.debug = __bind(this.debug, this);
      this.warn = __bind(this.warn, this);
      this.info = __bind(this.info, this);
      if ((_ref2 = (_base = this.options).srcmap) == null) {
        _base.srcmap = false;
      }
      if ((_ref3 = (_base1 = this.options).target) == null) {
        _base1.target = null;
      }
      if ((_ref4 = (_base2 = this.options).staticRoot) == null) {
        _base2.staticRoot = null;
      }
      if ((_ref5 = (_base3 = this.options).staticRootUrl) == null) {
        _base3.staticRootUrl = '/';
      }
      if ((_ref6 = (_base4 = this.options).src) == null) {
        _base4.src = '.';
      }
      if ((_ref7 = (_base5 = this.options).async) == null) {
        _base5.async = true;
      }
      this.cache = {};
      this.concatCache = {};
      this.depGraph = new DepGraph;
      this.logLevels = ['info', 'warn', 'debug', 'error'];
      if (this.options.srcmap) {
        if (!((this.options.staticRoot != null) || (this.options.target != null))) {
          if ((this.options.staticRoot == null) && (this.options.target == null)) {
            errorStr = 'both of the options \'staticRoot\' and \'target\'';
          } else if ((this.options.staticRoot != null) && (this.options.target == null)) {
            errorStr = '\'target\' option';
          } else if ((this.options.staticRoot == null) && (this.options.target != null)) {
            errorStr = '\'staticRoot\' option';
          }
          throw new Error("When generating source maps                         " + errorStr + " must be provided.");
        }
      }
    }

    Snockets.prototype.log = function(args, level) {
      if (_.contains(this.logLevels, level)) {
        return console.log.apply(console, args);
      }
    };

    Snockets.prototype.info = function() {
      var args;

      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.log(args, 'info');
    };

    Snockets.prototype.warn = function() {
      var args;

      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.log(args, 'warn');
    };

    Snockets.prototype.debug = function() {
      var args;

      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.log(args, 'debug');
    };

    Snockets.prototype.error = function() {
      var args;

      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.log(args, 'error');
    };

    Snockets.prototype.scan = function(filePath, flags, callback) {
      var _ref2,
        _this = this;

      if (typeof flags === 'function') {
        callback = flags;
        flags = {};
      }
      if (flags == null) {
        flags = {};
      }
      if ((_ref2 = flags.async) == null) {
        flags.async = this.options.async;
      }
      return this.updateDirectives(filePath, flags, function(err, graphChanged) {
        if (err) {
          if (callback) {
            return callback(err);
          } else {
            throw err;
          }
        }
        if (typeof callback === "function") {
          callback(null, _this.depGraph, graphChanged);
        }
        return _this.depGraph;
      });
    };

    Snockets.prototype.getCompiledChain = function(filePath, flags, callback) {
      var _ref2,
        _this = this;

      if (typeof flags === 'function') {
        callback = flags;
        flags = {};
      }
      if (flags == null) {
        flags = {};
      }
      if ((_ref2 = flags.async) == null) {
        flags.async = this.options.async;
      }
      return this.updateDirectives(filePath, flags, function(err, graphChanged) {
        var chain, compiledChain, e, link, o;

        if (err) {
          if (callback) {
            return callback(err);
          } else {
            throw err;
          }
        }
        try {
          chain = _this.depGraph.getChain(filePath);
        } catch (_error) {
          e = _error;
          if (callback) {
            return callback(e);
          } else {
            throw e;
          }
        }
        compiledChain = (function() {
          var _i, _len, _ref3, _results;

          _ref3 = chain.concat(filePath);
          _results = [];
          for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
            link = _ref3[_i];
            o = {};
            if (this.compileFile(link)) {
              o.filename = stripExt(link) + '.js';
            } else {
              o.filename = link;
            }
            o.js = this.cache[link].js.toString('utf8');
            _results.push(o);
          }
          return _results;
        }).call(_this);
        if (typeof callback === "function") {
          callback(null, compiledChain, graphChanged);
        }
        return compiledChain;
      });
    };

    Snockets.prototype.getConcatenation = function(filePath, flags, callback) {
      var concatenationChanged, _ref2,
        _this = this;

      if (typeof flags === 'function') {
        callback = flags;
        flags = {};
      }
      if (flags == null) {
        flags = {};
      }
      if ((_ref2 = flags.async) == null) {
        flags.async = this.options.async;
      }
      concatenationChanged = true;
      return this.updateDirectives(filePath, flags, function(err, graphChanged) {
        var absLink, cacheMiss, cacheValid, cached, catjs, catmaps, chain, concatenation, doMinify, doSrcMap, hasData, hasMinData, hasSrcMap, isCompiled, js, link, minopts, numLines, result, sources, srcmap, targetUrl, toMinify, _cacheValid, _err, _hasJs, _hasMinData, _hasSrcMap, _i, _len, _maps, _mindata, _sources, _srcmap;

        if (err) {
          if (callback) {
            return callback(err);
          } else {
            throw err;
          }
          return;
        }
        doSrcMap = _this.options.srcmap;
        doMinify = flags.minify;
        if (doSrcMap && !doMinify) {
          doSrcMap = false;
          _this.warn("Disabling srcmap generation due to no minification. [" + filePath + "]");
        }
        if (_this.concatCache[filePath] == null) {
          _this.concatCache[filePath] = {};
        }
        cacheValid = false;
        hasData = _this.concatCache[filePath].data != null;
        hasMinData = _this.concatCache[filePath].minifiedData != null;
        hasSrcMap = _this.concatCache[filePath].srcmap != null;
        if (!(doSrcMap && doMinify)) {
          if (hasData) {
            cacheValid = true;
          }
        }
        if (!doSrcMap && doMinify) {
          cacheValid = hasMinData ? true : false;
        }
        if (doSrcMap && doMinify) {
          if (hasSrcMap && hasMinData) {
            cacheValid = true;
          }
        }
        try {
          if (cacheValid && !doMinify) {
            concatenation = _this.concatCache[filePath].data.toString('utf8');
            concatenationChanged = false;
          } else if (cacheValid && doMinify && !doSrcMap) {
            concatenation = _this.concatCache[filePath].minifiedData.toString('utf8');
            concatenationChanged = false;
          } else if (cacheValid && doMinify && doSrcMap) {
            js = _this.concatCache[filePath].minifiedData.toString('utf8');
            srcmap = _this.concatCache[filePath].srcmap;
            concatenation = {
              js: js,
              srcmap: srcmap
            };
            concatenationChanged = false;
          } else {
            _this.concatCache[filePath].maps = {};
            chain = _this.depGraph.getChain(filePath).concat(filePath);
            cacheMiss = false;
            sources = [];
            for (_i = 0, _len = chain.length; _i < _len; _i++) {
              link = chain[_i];
              isCompiled = _this.compileFile(link);
              cached = _this.cache[link];
              if (cached == null) {
                continue;
              }
              _hasJs = cached.js != null;
              _hasMinData = cached.minifiedData != null;
              _hasSrcMap = cached.srcmap != null;
              _cacheValid = false;
              if (!doMinify) {
                _cacheValid = _hasJs ? true : false;
              }
              if (!doSrcMap && doMinify) {
                _cacheValid = _hasMinData ? true : false;
              }
              if (doSrcMap && !doMinify) {
                _cacheValid = _hasSrcMap && _hasJs ? true : false;
              }
              if (doSrcMap && doMinify) {
                _cacheValid = _hasSrcMap && _hasMinData ? true : false;
              }
              if (_cacheValid && !doMinify && !doSrcMap) {
                sources.push(cached.js.toString('utf8'));
              } else if (_cacheValid && doMinify && !doSrcMap) {
                sources.push(cached.minifiedData.toString('utf8'));
              } else if (_cacheValid && doMinify && doSrcMap) {
                sources.push({
                  js: cached.minifiedData.toString('utf8'),
                  srcmap: cached.srcmap
                });
              } else if (_cacheValid && !doMinify && doSrcMap) {
                js = cached.js.toString('utf8');
                if (cached.srcmap == null) {
                  numLines = js.split(/\r\n|\r|\n/gm).length;
                  cached.srcmap = {
                    empty: true,
                    numLines: numLines,
                    file: link
                  };
                }
                sources.push({
                  js: js,
                  srcmap: cached.srcmap
                });
              } else {
                cacheMiss = true;
                _srcmap = null;
                _mindata = null;
                minopts = {};
                if (doSrcMap) {
                  absLink = path.resolve(_this.options.src, link);
                  minopts.outname = "" + (stripExt(absLink)) + ".js";
                  minopts.srcmap = true;
                  minopts.inname = absLink;
                  minopts.staticRoot = _this.options.staticRoot;
                  minopts.staticRootUrl = _this.options.staticRootUrl;
                }
                if (isCompiled && _hasSrcMap && doSrcMap) {
                  minopts.srcmap = cached.srcmap;
                }
                toMinify = cached.js.toString('utf8');
                if (doMinify) {
                  result = minify(toMinify, minopts);
                } else {
                  if (doSrcMap) {
                    if (isCompiled) {
                      result = {
                        srcmap: cached.srcmap,
                        js: toMinify
                      };
                    } else {
                      numLines = toMinify.split(/\r\n|\r|\n/gm).length;
                      result = {
                        srcmap: {
                          empty: true,
                          numLines: numLines,
                          file: link
                        },
                        js: toMinify
                      };
                    }
                  } else {
                    result = toMinify;
                  }
                }
                if (doSrcMap) {
                  _srcmap = result.srcmap;
                  _mindata = new Buffer(result.js);
                  sources.push({
                    srcmap: _srcmap,
                    js: result.js
                  });
                } else {
                  _mindata = new Buffer(result);
                  sources.push(result);
                }
                cached.minifiedData = _mindata;
                cached.srcmap = _srcmap;
              }
            }
            if (cacheMiss) {
              concatenationChanged = true;
            } else {
              concatenationChanged = false;
            }
            if (!doSrcMap) {
              concatenation = sources.join('\n');
            } else {
              _sources = _.pluck(sources, 'js');
              _maps = _.pluck(sources, 'srcmap');
              catjs = _sources.join('\n');
              targetUrl = getUrlPath(_this.options.target, _this.options.staticRoot, _this.options.staticRootUrl);
              catmaps = sourceMapCat({
                filename: targetUrl,
                maps: _maps
              });
              concatenation = {
                js: catjs,
                srcmap: catmaps
              };
            }
          }
        } catch (_error) {
          _err = _error;
          throw _err;
          return;
        }
        if (!(doMinify || doSrcMap)) {
          _this.concatCache[filePath].data = new Buffer(concatenation);
        } else if (doMinify && !doSrcMap) {
          _this.concatCache[filePath].minifiedData = new Buffer(concatenation);
        } else if (doMinify && doSrcMap) {
          _this.concatCache[filePath].minifiedData = new Buffer(concatenation.js);
          _this.concatCache[filePath].srcmap = concatenation.srcmap;
        } else if (!doMinify && doSrcMap) {
          _this.concatCache[filePath].data = new Buffer(concatenation.js);
          _this.concatCache[filePath].srcmap = concatenation.srcmap;
        }
        if (typeof callback === "function") {
          callback(null, concatenation, concatenationChanged);
        }
        return concatenation;
      });
    };

    Snockets.prototype.updateDirectives = function() {
      var callback, depList, excludes, filePath, flags, graphChanged, q, require, requireTree, _i,
        _this = this;

      filePath = arguments[0], flags = arguments[1], excludes = 4 <= arguments.length ? __slice.call(arguments, 2, _i = arguments.length - 1) : (_i = 2, []), callback = arguments[_i++];
      if (__indexOf.call(excludes, filePath) >= 0) {
        return callback();
      }
      excludes.push(filePath);
      depList = [];
      graphChanged = false;
      q = new HoldingQueue({
        task: function(depPath, next) {
          var err, _ref2;

          if (_ref2 = path.extname(depPath), __indexOf.call(jsExts(), _ref2) < 0) {
            return next();
          }
          if (depPath === filePath) {
            err = new Error("Script tries to require itself: " + filePath);
            return callback(err);
          }
          if (__indexOf.call(depList, depPath) < 0) {
            depList.push(depPath);
          }
          return _this.updateDirectives.apply(_this, [depPath, flags].concat(__slice.call(excludes), [function(err, depChanged) {
            if (err) {
              return callback(err);
            }
            graphChanged || (graphChanged = depChanged);
            return next();
          }]));
        },
        onComplete: function() {
          if (!_.isEqual(depList, _this.depGraph.map[filePath])) {
            _this.depGraph.map[filePath] = depList;
            graphChanged = true;
          }
          if (graphChanged) {
            _this.concatCache[filePath] = null;
          }
          return callback(null, graphChanged);
        }
      });
      require = function(relPath) {
        var depName, depPath, relName;

        q.waitFor(relName = stripExt(relPath));
        if (relName.match(EXPLICIT_PATH)) {
          depPath = relName + '.js';
          return q.perform(relName, depPath);
        } else {
          depName = _this.joinPath(path.dirname(filePath), relName);
          return _this.findMatchingFile(depName, flags, function(err, depPath) {
            if (err) {
              return callback(err);
            }
            return q.perform(relName, depPath);
          });
        }
      };
      requireTree = function(dirName) {
        q.waitFor(dirName);
        return _this.readdir(_this.absPath(dirName), flags, function(err, items) {
          var item, itemPath, _j, _len, _results;

          if (err) {
            return callback(err);
          }
          q.unwaitFor(dirName);
          _results = [];
          for (_j = 0, _len = items.length; _j < _len; _j++) {
            item = items[_j];
            itemPath = _this.joinPath(dirName, item);
            if (_this.absPath(itemPath) === _this.absPath(filePath)) {
              continue;
            }
            q.waitFor(itemPath);
            _results.push((function(itemPath) {
              return _this.stat(_this.absPath(itemPath), flags, function(err, stats) {
                if (err) {
                  return callback(err);
                }
                if (stats.isFile()) {
                  return q.perform(itemPath, itemPath);
                } else {
                  requireTree(itemPath);
                  return q.unwaitFor(itemPath);
                }
              });
            })(itemPath));
          }
          return _results;
        });
      };
      return this.readFile(filePath, flags, function(err, fileChanged) {
        var command, directive, relPath, relPaths, words, _j, _k, _l, _len, _len1, _len2, _ref2;

        if (err) {
          return callback(err);
        }
        if (fileChanged) {
          graphChanged = true;
        }
        _ref2 = parseDirectives(_this.cache[filePath].data.toString('utf8'));
        for (_j = 0, _len = _ref2.length; _j < _len; _j++) {
          directive = _ref2[_j];
          words = directive.replace(/['"]/g, '').split(/\s+/);
          command = words[0], relPaths = 2 <= words.length ? __slice.call(words, 1) : [];
          switch (command) {
            case 'require':
              for (_k = 0, _len1 = relPaths.length; _k < _len1; _k++) {
                relPath = relPaths[_k];
                require(relPath);
              }
              break;
            case 'require_tree':
              for (_l = 0, _len2 = relPaths.length; _l < _len2; _l++) {
                relPath = relPaths[_l];
                requireTree(_this.joinPath(path.dirname(filePath), relPath));
              }
          }
        }
        return q.finalize();
      });
    };

    Snockets.prototype.findMatchingFile = function(filename, flags, callback) {
      var tryFiles,
        _this = this;

      tryFiles = function(filePaths) {
        var filePath, _i, _len;

        for (_i = 0, _len = filePaths.length; _i < _len; _i++) {
          filePath = filePaths[_i];
          if (stripExt(_this.absPath(filePath)) === _this.absPath(filename)) {
            callback(null, filePath);
            return true;
          }
        }
      };
      if (tryFiles(_.keys(this.cache))) {
        return;
      }
      return this.readdir(path.dirname(this.absPath(filename)), flags, function(err, files) {
        var file;

        if (err) {
          return callback(err);
        }
        if (tryFiles((function() {
          var _i, _len, _results;

          _results = [];
          for (_i = 0, _len = files.length; _i < _len; _i++) {
            file = files[_i];
            _results.push(this.joinPath(path.dirname(filename), file));
          }
          return _results;
        }).call(_this))) {
          return;
        }
        return callback(new Error("File not found: '" + filename + "'"));
      });
    };

    Snockets.prototype.readdir = function(dir, flags, callback) {
      var e, files;

      if (flags.async) {
        return fs.readdir(this.absPath(dir), callback);
      } else {
        try {
          files = fs.readdirSync(this.absPath(dir));
          return callback(null, files);
        } catch (_error) {
          e = _error;
          return callback(e);
        }
      }
    };

    Snockets.prototype.stat = function(filePath, flags, callback) {
      var e, stats;

      if (flags.async) {
        return fs.stat(this.absPath(filePath), callback);
      } else {
        try {
          stats = fs.statSync(this.absPath(filePath));
          return callback(null, stats);
        } catch (_error) {
          e = _error;
          return callback(e);
        }
      }
    };

    Snockets.prototype.readFile = function(filePath, flags, callback) {
      var _this = this;

      return this.stat(filePath, flags, function(err, stats) {
        var data, e, _ref2;

        if (err) {
          return callback(err);
        }
        if (timeEq((_ref2 = _this.cache[filePath]) != null ? _ref2.mtime : void 0, stats.mtime)) {
          return callback(null, false);
        }
        if (flags.async) {
          return fs.readFile(_this.absPath(filePath), function(err, data) {
            if (err) {
              return callback(err);
            }
            _this.cache[filePath] = {
              mtime: stats.mtime,
              data: data
            };
            return callback(null, true);
          });
        } else {
          try {
            data = fs.readFileSync(_this.absPath(filePath));
            _this.cache[filePath] = {
              mtime: stats.mtime,
              data: data
            };
            return callback(null, true);
          } catch (_error) {
            e = _error;
            return callback(e);
          }
        }
      });
    };

    Snockets.prototype.compileFile = function(filePath) {
      var ext, js, pth, src;

      if ((ext = path.extname(filePath)) === '.js') {
        this.cache[filePath].js = this.cache[filePath].data;
        return false;
      } else {
        src = this.cache[filePath].data.toString('utf8');
        pth = this.absPath(filePath);
        js = compilers[ext.slice(1)].compileSync(this.absPath(filePath), src, this.options);
        if (!_.isString(js)) {
          this.cache[filePath].srcmap = js.srcmap;
          js = js.js;
        }
        this.cache[filePath].js = new Buffer(js);
        return true;
      }
    };

    Snockets.prototype.absPath = function(relPath) {
      if (relPath.match(EXPLICIT_PATH)) {
        return relPath;
      } else if (this.options.src.match(EXPLICIT_PATH)) {
        return this.joinPath(this.options.src, relPath);
      } else {
        return this.joinPath(process.cwd(), this.options.src, relPath);
      }
    };

    Snockets.prototype.joinPath = function() {
      var filePath, slash;

      filePath = path.join.apply(path, arguments);
      if (process.platform === 'win32') {
        slash = '/';
        return filePath.replace(/\\/g, slash);
      } else {
        return filePath;
      }
    };

    return Snockets;

  })();

  module.exports.compilers = compilers;

  EXPLICIT_PATH = /^\/|:/;

  HEADER = /(?:(\#\#\#.*\#\#\#\n*)|(\/\/.*\n*)|(\#.*\n*))+/;

  DIRECTIVE = /^[\W]*=\s*(\w+.*?)(\*\\\/)?$/gm;

  HoldingQueue = (function() {
    function HoldingQueue(_arg) {
      this.task = _arg.task, this.onComplete = _arg.onComplete;
      this.holdKeys = [];
    }

    HoldingQueue.prototype.waitFor = function(key) {
      return this.holdKeys.push(key);
    };

    HoldingQueue.prototype.unwaitFor = function(key) {
      return this.holdKeys = _.without(this.holdKeys, key);
    };

    HoldingQueue.prototype.perform = function() {
      var args, key,
        _this = this;

      key = arguments[0], args = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
      return this.task.apply(this, __slice.call(args).concat([function() {
        return _this.unwaitFor(key);
      }]));
    };

    HoldingQueue.prototype.finalize = function() {
      var h,
        _this = this;

      if (this.holdKeys.length === 0) {
        return this.onComplete();
      } else {
        return h = setInterval((function() {
          if (_this.holdKeys.length === 0) {
            _this.onComplete();
            return clearInterval(h);
          }
        }), 10);
      }
    };

    return HoldingQueue;

  })();

  parseDirectives = function(code) {
    var header, match, _results;

    code = code.replace(/[\r\t ]+$/gm, '\n');
    if (!(match = HEADER.exec(code))) {
      return [];
    }
    header = match[0];
    _results = [];
    while (match = DIRECTIVE.exec(header)) {
      _results.push(match[1]);
    }
    return _results;
  };

  sourceMapCat = function(opts) {
    var combinedGeneratedLine, generated, original, originalLastLine, _i, _len, _original, _ref2;

    generated = new SourceMap.SourceMapGenerator({
      file: opts.filename
    });
    combinedGeneratedLine = 1;
    _ref2 = opts.maps;
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      _original = _ref2[_i];
      if ((_original.empty != null) && _original.empty === true) {
        combinedGeneratedLine += _original.numLines;
        continue;
      }
      original = new SourceMap.SourceMapConsumer(_original);
      originalLastLine = null;
      original.eachMapping(function(mapping) {
        var e;

        try {
          generated.addMapping({
            generated: {
              line: combinedGeneratedLine + mapping.generatedLine,
              column: mapping.generatedColumn
            },
            original: {
              line: mapping.originalLine,
              column: mapping.originalColumn
            },
            source: mapping.source
          });
        } catch (_error) {
          e = _error;
          throw new Error("Invalid Mapping: " + (JSON.stringify(mapping)));
        }
        return originalLastLine = mapping.generatedLine;
      });
      combinedGeneratedLine += originalLastLine;
    }
    return JSON.parse(generated.toString());
  };

}).call(this);
