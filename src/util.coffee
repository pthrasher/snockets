path = require 'path'

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

module.exports = {
    timeEq
    getUrlPath
}
