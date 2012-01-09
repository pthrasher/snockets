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
    traversedPaths.unshift id
    traversedBranch.unshift id
    return [] unless @map[id]

    depIds = @map[id]
    for depId in depIds.slice(0).reverse()
      if depId in traversedBranch          # cycle
        throw new Error("Cyclic dependency from #{id} to #{depId}")
      if depId in traversedPaths          # duplicate, push to front
        depIdIndex = traversedPaths.indexOf depId
        traversedPaths[depIdIndex..depIdIndex] = []
        traversedPaths.unshift depId
        continue

      @getChain depId, traversedPaths, traversedBranch.slice(0)

    traversedPaths[0...-1]

# Export the class in Node, make it global in the browser.
if module?.exports?
  module.exports = DepGraph
else
  @DepGraph = DepGraph