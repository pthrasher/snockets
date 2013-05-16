Snockets = require '../lib/snockets'
path     = require 'path'
src      = 'spec/assets'

# Jasmine.Async, v0.1.0
# Copyright (c)2012 Muted Solutions, LLC. All Rights Reserved.
# Distributed under MIT license
# http://github.com/derickbailey/jasmine.async
runAsync = (block) ->
    ->
        done = false
        complete = ->
            done = true

        runs ->
            block complete

        waitsFor ->
            done

class AsyncSpec
    constructor: (@spec) ->

    beforeEach: (block) ->
        @spec.beforeEach runAsync(block)

    afterEach: (block) ->
        @spec.afterEach runAsync(block)

    it: (description, block) ->
        global.it description, runAsync(block)


describe 'Snockets Legacy API', ->

    snockets = null
    async = new AsyncSpec(@)

    beforeEach ->
        snockets = new Snockets { src }

    afterEach ->
        snockets = null

    describe 'doesn\'t find dependencies for independant js files', ->
        async.it 'async', (done) ->
            snockets.scan 'b.js', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.map['b.js']).toBeDefined()
                expect(snockets.depGraph.getChain 'b.js').toEqual []
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'b.js'
            expect(snockets.depGraph.map['b.js']).toBeDefined()
            expect(snockets.depGraph.getChain 'b.js').toEqual []

    describe 'Single-step dependencies are correctly recorded', ->
        async.it 'async', (done) ->
            snockets.scan 'a.coffee', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.getChain('a.coffee')).toEqual ['b.js']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'a.coffee'
            expect(snockets.depGraph.getChain('a.coffee')).toEqual ['b.js']

    describe 'Dependencies with multiple extensions are accepted', ->
        async.it 'async', (done) ->
            snockets.scan 'testing.js', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.getChain('testing.js')).toEqual ['1.2.3.coffee']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'testing.js'
            expect(snockets.depGraph.getChain('testing.js')).toEqual ['1.2.3.coffee']

    describe 'Dependencies can have subdirectory-relative paths', ->
        async.it 'async', (done) ->
            snockets.scan 'song/loveAndMarriage.js', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.getChain('song/loveAndMarriage.js')).toEqual ['song/horseAndCarriage.coffee']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'song/loveAndMarriage.js'
            expect(snockets.depGraph.getChain('song/loveAndMarriage.js')).toEqual ['song/horseAndCarriage.coffee']

    describe 'Multiple dependencies can be declared in one require directive', ->
        async.it 'async', (done) ->
            snockets.scan 'poly.coffee', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.getChain('poly.coffee')).toEqual ['b.js', 'x.coffee']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'poly.coffee'
            expect(snockets.depGraph.getChain('poly.coffee')).toEqual ['b.js', 'x.coffee']

    describe 'Chained dependencies are correctly recorded', ->
        async.it 'async', (done) ->
            snockets.scan 'z.coffee', (err) ->
                expect(err).toBeFalsy()
                expect(snockets.depGraph.getChain('z.coffee')).toEqual ['x.coffee', 'y.js']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'z.coffee'
            expect(snockets.depGraph.getChain('z.coffee')).toEqual ['x.coffee', 'y.js']

    describe 'Dependency cycles cause no errors during scanning', ->
        async.it 'async', (done) ->
            snockets.scan 'yin.js', (err) ->
                expect(err).toBeFalsy()
                expect(->
                    snockets.depGraph.getChain('yin.js')
                ).toThrow()
                expect(->
                    snockets.depGraph.getChain('yang.coffee')
                ).toThrow()
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'yin.js'
            expect(->
                snockets.depGraph.getChain('yin.js')
            ).toThrow()
            expect(->
                snockets.depGraph.getChain('yang.coffee')
            ).toThrow()

    describe 'require_tree works for same directory', ->
        expected = ['branch/edge.coffee', 'branch/periphery.js', 'branch/subbranch/leaf.js']

        async.it 'async', (done) ->
            snockets.scan 'branch/center.coffee', (err) ->
                expect(err).toBeFalsy()
                chain = snockets.depGraph.getChain('branch/center.coffee')
                expect(chain).toEqual expected
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'branch/center.coffee'
            chain = snockets.depGraph.getChain('branch/center.coffee')
            expect(chain).toEqual expected

    describe 'require works for includes that are relative to orig file using ../', ->
        async.it 'async', (done) ->
            snockets.scan 'first/syblingFolder.js', (err) ->
                expect(err).toBeFalsy()
                chain = snockets.depGraph.getChain('first/syblingFolder.js')
                expect(chain).toEqual ['sybling/sybling.js']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'first/syblingFolder.js'
            chain = snockets.depGraph.getChain('first/syblingFolder.js')
            expect(chain).toEqual ['sybling/sybling.js']

    describe 'require_tree works for nested directories', ->
        expectedChain = ['middleEarth/legolas.coffee', 'middleEarth/shire/bilbo.js', 'middleEarth/shire/frodo.coffee']
        async.it 'async', (done) ->
            snockets.scan 'fellowship.js', (err) ->
                expect(err).toBeFalsy()
                chain = snockets.depGraph.getChain('fellowship.js')
                expect(chain).toEqual expectedChain
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'fellowship.js'
            chain = snockets.depGraph.getChain('fellowship.js')
            expect(chain).toEqual expectedChain

    describe 'require_tree works for redundant directories', ->
        expectedChain = ['middleEarth/shire/bilbo.js', 'middleEarth/shire/frodo.coffee', 'middleEarth/legolas.coffee']
        async.it 'async', (done) ->
            snockets.scan 'trilogy.coffee', (err) ->
                expect(err).toBeFalsy()
                chain = snockets.depGraph.getChain('trilogy.coffee')
                expect(chain).toEqual expectedChain
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'trilogy.coffee'
            chain = snockets.depGraph.getChain('trilogy.coffee')
            expect(chain).toEqual expectedChain

    describe 'getCompiledChain returns correct .js filenames and code', ->
        expectedChain = [
            {filename: 'x.js', js: '(function() {\n  "Double rainbow\\nSO INTENSE";\n\n}).call(this);\n'}
            {filename: 'y.js', js: '//= require x'}
            {filename: 'z.js', js: '(function() {\n\n\n}).call(this);\n'}
        ]
        async.it 'async', (done) ->
            snockets.getCompiledChain 'z.coffee', (err, chain) ->
                expect(err).toBeFalsy()
                expect(chain).toEqual expectedChain
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.getCompiledChain 'z.coffee', (err, chain) ->
                expect(err).toBeFalsy()
                expect(chain).toEqual expectedChain

    describe 'getCompiledChain returns correct .js filenames and code with ../ in require path', ->
        expectedChain =  [
            {filename: 'sybling/sybling.js', js: 'var thereWillBeJS = 3;'}
            {filename: 'first/syblingFolder.js', js: '//= require ../sybling/sybling.js'}
        ]
        async.it 'async', (done) ->
            snockets.getCompiledChain 'first/syblingFolder.js', (err, chain) ->
                expect(err).toBeFalsy()
                expect(chain).toEqual expectedChain
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.getCompiledChain 'first/syblingFolder.js', (err, chain) ->
                expect(err).toBeFalsy()
                expect(chain).toEqual expectedChain

    describe 'getConcatenation returns correct raw JS code with ../ in require path', ->
        expectedContent = """
          var thereWillBeJS = 3;
          //= require ../sybling/sybling.js
        """
        async.it 'async', (done) ->
            snockets.getConcatenation 'first/syblingFolder.js', (err, js1, changed) ->
                expect(err).toBeFalsy()
                expect(js1).toEqual expectedContent
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.getConcatenation 'first/syblingFolder.js', (err, js1, changed) ->
                expect(err).toBeFalsy()
                expect(js1).toEqual expectedContent

    describe 'getConcatenation returns correct raw JS code', ->
        expectedContent = """
          (function() {\n  "Double rainbow\\nSO INTENSE";\n\n}).call(this);\n
          //= require x
          (function() {\n\n\n}).call(this);\n
        """
        async.it 'async', (done) ->
            snockets.getConcatenation 'z.coffee', (err, js1, changed) ->
                expect(err).toBeFalsy()
                expect(js1).toEqual expectedContent
                snockets.getConcatenation 'z.coffee', (err, js2, changed) ->
                    expect(err).toBeFalsy()
                    expect(!changed).toBe(true)
                    expect(js1).toEqual js2
                    done()

        it 'sync', ->
            snockets.options.async = false
            snockets.getConcatenation 'z.coffee', (err, js1, changed) ->
                expect(err).toBeFalsy()
                expect(js1).toEqual expectedContent
                snockets.getConcatenation 'z.coffee', (err, js2, changed) ->
                    expect(err).toBeFalsy()
                    expect(!changed).toBe(true)
                    expect(js1).toEqual js2

    describe 'getConcatenation returns correct minified JS code', ->
        expectedContent = """
          (function(){"Double rainbow\\nSO INTENSE"}).call(this);\n\n(function(){}).call(this);
        """
        async.it 'async', (done) ->
            snockets.getConcatenation 'z.coffee', minify: true, (err, js) ->
                expect(err).toBeFalsy()
                expect(js).toEqual expectedContent
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.getConcatenation 'z.coffee', minify: true, (err, js) ->
                expect(err).toBeFalsy()
                expect(js).toEqual expectedContent

    describe 'getConcatenation caches minified JS code', ->
        async.it 'async', (done) ->
            flags = minify: true
            snockets.getConcatenation 'jquery-1.6.4.js', flags, (err, js, changed) ->
                expect(err).toBeFalsy()
                startTime = +new Date
                snockets.getConcatenation 'jquery-1.6.4.js', flags, (err, js, changed) ->
                    expect(err).toBeFalsy()
                    expect(!changed).toBe(true)
                    endTime = +new Date
                    expect(endTime - startTime).toBeLessThan 10
                    done()

        it 'sync', ->
            snockets.options.async = false
            flags = minify: true
            snockets.getConcatenation 'jquery-1.6.4.js', flags, (err, js, changed) ->
                expect(err).toBeFalsy()
                startTime = +new Date
                snockets.getConcatenation 'jquery-1.6.4.js', flags, (err, js, changed) ->
                    expect(err).toBeFalsy()
                    expect(!changed).toBe(true)
                    endTime = +new Date
                    expect(endTime - startTime).toBeLessThan 10

    describe 'getConcatenation returns correct minified JS code and srcmap', ->

        async.it 'async', (done) ->
            staticRoot = path.resolve snockets.options.src
            target = path.resolve staticRoot, 'all.js'
            snockets.options.srcmap = true
            snockets.options.staticRoot = staticRoot
            snockets.options.target = target
            snockets.options.staticRootUrl = '/assets/'
            snockets.getConcatenation 'z.coffee', minify: true, (err, result) ->
                expect(err).toBeFalsy()
                { js, srcmap } = result
                expect(js).toEqual """
                  (function(){"Double rainbow\\nSO INTENSE"}).call(this);\n\n(function(){}).call(this);
                """
                expect(srcmap.file).toEqual "/assets/all.js"
                expect(srcmap.sources[0]).toEqual "/assets/x.coffee"
                expect(srcmap.sources[1]).toEqual "/assets/z.coffee"
                expect(srcmap.mappings).toEqual ";CAAA,WAAA,+BAAA,KAAA;CCGG,cAAA,KAAA"
                done()

        it 'sync', ->
            snockets.options.async = false
            staticRoot = path.resolve snockets.options.src
            target = path.resolve staticRoot, 'all.js'
            snockets.options.srcmap = true
            snockets.options.staticRoot = staticRoot
            snockets.options.target = target
            snockets.options.staticRootUrl = '/assets/'
            snockets.getConcatenation 'z.coffee', minify: true, (err, result) ->
                expect(err).toBeFalsy()
                { js, srcmap } = result
                expect(js).toEqual """
                  (function(){"Double rainbow\\nSO INTENSE"}).call(this);\n\n(function(){}).call(this);
                """
                expect(srcmap.file).toEqual "/assets/all.js"
                expect(srcmap.sources[0]).toEqual "/assets/x.coffee"
                expect(srcmap.sources[1]).toEqual "/assets/z.coffee"
                expect(srcmap.mappings).toEqual ";CAAA,WAAA,+BAAA,KAAA;CCGG,cAAA,KAAA"
