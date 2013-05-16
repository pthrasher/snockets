(function() {
  var DIRECTIVE, EXPLICIT_PATH, HEADER, HoldingQueue, SourceMap, getUrlPath, parseDirectives, path, sourceMapCat, timeEq, _,
    __slice = [].slice;

  path = require('path');

  _ = require('underscore');

  SourceMap = require('source-map');

  EXPLICIT_PATH = /^\/|:/;

  HEADER = /(?:(\#\#\#.*\#\#\#\n*)|(\/\/.*\n*)|(\#.*\n*))+/;

  DIRECTIVE = /^[\W]*=\s*(\w+.*?)(\*\\\/)?$/gm;

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

  timeEq = function(date1, date2) {
    return (date1 != null) && (date2 != null) && date1.getTime() === date2.getTime();
  };

  getUrlPath = function(absPath, absStaticRoot, staticRootUrl) {
    absPath = path.resolve(path.normalize(absPath));
    absStaticRoot = path.resolve(path.normalize(absStaticRoot));
    if (absStaticRoot[absStaticRoot.length - 1] !== '/') {
      absStaticRoot += '/';
    }
    if (staticRootUrl[staticRootUrl.length - 1] !== '/') {
      staticRootUrl += '/';
    }
    return absPath.replace(absStaticRoot, staticRootUrl);
  };

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

  sourceMapCat = function(opts) {
    var combinedGeneratedLine, generated, original, originalLastLine, _i, _len, _original, _ref;

    generated = new SourceMap.SourceMapGenerator({
      file: opts.filename
    });
    combinedGeneratedLine = 1;
    _ref = opts.maps;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _original = _ref[_i];
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

  module.exports = {
    timeEq: timeEq,
    getUrlPath: getUrlPath,
    HoldingQueue: HoldingQueue,
    parseDirectives: parseDirectives,
    sourceMapCat: sourceMapCat,
    EXPLICIT_PATH: EXPLICIT_PATH,
    DIRECTIVE: DIRECTIVE,
    HEADER: HEADER
  };

}).call(this);
