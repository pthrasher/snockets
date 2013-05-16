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

	async.it 'doesn\'t find dependencies for independant js files', (done) ->

		snockets.scan 'b.js', (err) ->
			throw err if err
			expect(snockets.depGraph.map['b.js']).toBeDefined()
			expect(snockets.depGraph.getChain 'b.js').toEqual []
			done()


