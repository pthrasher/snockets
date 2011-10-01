Snockets = require '../lib/snockets'
src = '../test/assets'
snockets = new Snockets({src})

testSuite =
  'Independent JS files have no dependencies': (test) ->
    snockets.scan 'b.js', (err) ->
      throw err if err
      test.ok snockets.depGraph.map['b.js']
      test.deepEqual snockets.depGraph.getChain('b.js'), []
      test.done()

  'Single-step dependencies are correctly recorded': (test) ->
    snockets.scan 'a.coffee', (err) ->
      throw err if err
      test.deepEqual snockets.depGraph.getChain('a.coffee'), ['b.js']
      test.done()

  'Chained dependencies are correctly recorded': (test) ->
    snockets.scan 'z.coffee', (err) ->
      throw err if err
      test.deepEqual snockets.depGraph.getChain('z.coffee'), ['x.coffee', 'y.js']
      test.done()

  'Dependency cycles cause no errors during scanning': (test) ->
    snockets.scan 'yin.js', (err) ->
      throw err if err
      test.throws -> snockets.depGraph.getChain('yin.js')
      test.throws -> snockets.depGraph.getChain('yang.coffee')
      test.done()

  'require_tree works for same directory': (test) ->
    snockets.scan 'branch/center.coffee', (err) ->
      throw err if err
      chain = snockets.depGraph.getChain('branch/center.coffee')
      test.deepEqual chain, ['branch/edge.coffee', 'branch/periphery.js']
      test.done()

  'getCompiledChain returns correct .js filenames and code': (test) ->
    snockets.getCompiledChain 'z.coffee', (err, chain) ->
      throw err if err
      console.log chain
      # test.deepEqual snockets.depGraph.getChain('z.coffee'), ['x.coffee', 'y.js']
      test.done()

# Every test runs both synchronously and asynchronously.
for name, func of testSuite
  do (func) ->
    exports[name] = (test) ->
      snockets.options.async = true;  func(test)
    exports[name + ' (sync)'] = (test) ->
      snockets.options.async = false; func(test)