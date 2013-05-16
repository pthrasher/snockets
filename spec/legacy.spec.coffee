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
                throw err if err
                expect(snockets.depGraph.map['b.js']).toBeDefined()
                expect(snockets.depGraph.getChain 'b.js').toEqual []
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'b.js', ->
            expect(snockets.depGraph.map['b.js']).toBeDefined()
            expect(snockets.depGraph.getChain 'b.js').toEqual []

    describe 'Single-step dependencies are correctly recorded', ->
        async.it 'async', (done) ->
            snockets.scan 'a.coffee', (err) ->
                throw err if err
                expect(snockets.depGraph.getChain('a.coffee')).toEqual ['b.js']
                done()

        it 'sync', ->
            snockets.options.async = false
            snockets.scan 'a.coffee', ->
            expect(snockets.depGraph.getChain('a.coffee')).toEqual ['b.js']

    xdescribe '', ->
        async.it 'async', (done) ->

        it 'sync', ->
            snockets.options.async = false


