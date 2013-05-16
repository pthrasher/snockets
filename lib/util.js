(function() {
  var getUrlPath, path, timeEq;

  path = require('path');

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

  module.exports = {
    timeEq: timeEq,
    getUrlPath: getUrlPath
  };

}).call(this);
