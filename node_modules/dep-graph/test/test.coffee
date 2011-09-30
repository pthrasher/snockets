DepGraph = require('../lib/dep-graph.js')
depGraph = new DepGraph

exports['Direct dependencies are chained in original order'] = (test) ->
  depGraph.add '0', '1'
  depGraph.add '0', '2'
  depGraph.add '0', '3'
  test.deepEqual depGraph.getChain('0'), ['1', '2', '3']
  test.done()

exports['Indirect dependencies are chained before their dependents'] = (test) ->
  depGraph.add '2', 'A'
  depGraph.add '2', 'B'
  test.deepEqual depGraph.getChain('0'), ['1', 'A', 'B', '2', '3']
  test.done()

exports['getChain can safely be called for unknown resources'] = (test) ->
  test.doesNotThrow -> depGraph.getChain('Z')
  test.deepEqual depGraph.getChain('Z'), []
  test.done()