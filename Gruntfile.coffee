module.exports = (grunt) ->
    grunt.initConfig
        coffee:
            compile:
                expand: true
                flatten: true
                cwd: '.'
                src: ['src/*.coffee']
                dest: 'lib/'
                ext: '.js'

        docco:
            compile:
                src: ['src/*.coffee']
                options:
                    output: 'dev-docs/'

        jasmine_node:
            projectRoot: "."
            requirejs: false
            forceExit: true
            extensions: 'coffee'

        coffeelint:
            app: ['src/*.coffee', 'Gruntfile.coffee']
            options:
                indentation:
                    value: 4
        watch:
            main:
                files: ['src/*.coffee']
                tasks: ['coffee', 'jasmine_node']

    grunt.loadNpmTasks 'grunt-jasmine-node'
    grunt.loadNpmTasks 'grunt-contrib-coffee'
    grunt.loadNpmTasks 'grunt-contrib-watch'
    grunt.loadNpmTasks 'grunt-docco'
    grunt.loadNpmTasks 'grunt-coffeelint'
    grunt.loadNpmTasks 'grunt-bump'

    grunt.registerTask 'default',
        ['coffeelint', 'coffee', 'jasmine_node', 'docco']
    grunt.registerTask 'test',
        ['coffee', 'jasmine_node']
