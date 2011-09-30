# [dep-graph](http://github.com/TrevorBurnham/dep-graph)

class DepGraph
  constructor: ->
    # The internal representation of the dependency graph in the format
    # `id: [ids]`, indicating only *direct* dependencies.
    @map = {}

  # Add a direct dependency. Returns `false` if that dependency is a duplicate.
  add: (id, depId) ->
    @map[id] ?= []
    return false if depId in @map[id]
    @map[id].push depId
    @map[id]

  # Generate a list of all dependencies (direct and indirect) for the given id,
  # in logical order with no duplicates.
  getChain: (id, traversedPaths = [], traversedBranch = []) ->
    return [] unless @map[id]

    for depId in @map[id].slice(0).reverse()
      if depId in traversedBranch          # cycle
          throw new Error("Cyclic dependency from #{id} to #{depId}")
      continue if depId in traversedPaths  # duplicate
      traversedPaths.unshift depId
      traversedBranch.unshift depId
      @getChain depId, traversedPaths, traversedBranch.slice(0)

    traversedPaths

# Export the class in Node, make it global in the browser.
if module?.exports?
  module.exports = DepGraph
else
  @DepGraph = DepGraph