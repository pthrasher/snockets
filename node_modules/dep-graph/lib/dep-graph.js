(function() {
  var DepGraph;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  DepGraph = (function() {
    function DepGraph() {
      this.map = {};
    }
    DepGraph.prototype.add = function(id, depId) {
      var _base, _ref;
      if ((_ref = (_base = this.map)[id]) == null) {
        _base[id] = [];
      }
      if (__indexOf.call(this.map[id], depId) >= 0) {
        return false;
      }
      this.map[id].push(depId);
      return this.map[id];
    };
    DepGraph.prototype.getChain = function(id, traversedPaths, traversedBranch) {
      var depId, depIdIndex, depIds, _i, _len, _ref, _ref2;
      if (traversedPaths == null) {
        traversedPaths = [];
      }
      if (traversedBranch == null) {
        traversedBranch = [];
      }
      traversedPaths.unshift(id);
      traversedBranch.unshift(id);
      if (!this.map[id]) {
        return [];
      }
      depIds = this.map[id];
      _ref = depIds.slice(0).reverse();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        depId = _ref[_i];
        if (__indexOf.call(traversedBranch, depId) >= 0) {
          throw new Error("Cyclic dependency from " + id + " to " + depId);
        }
        if (__indexOf.call(traversedPaths, depId) >= 0) {
          depIdIndex = traversedPaths.indexOf(depId);
          [].splice.apply(traversedPaths, [depIdIndex, depIdIndex - depIdIndex + 1].concat(_ref2 = [])), _ref2;
          traversedPaths.unshift(depId);
          continue;
        }
        this.getChain(depId, traversedPaths, traversedBranch.slice(0));
      }
      return traversedPaths.slice(0, -1);
    };
    return DepGraph;
  })();
  if ((typeof module !== "undefined" && module !== null ? module.exports : void 0) != null) {
    module.exports = DepGraph;
  } else {
    this.DepGraph = DepGraph;
  }
}).call(this);
