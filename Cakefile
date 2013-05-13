# copy from coffeekup
{spawn, exec} = require 'child_process'
run = (cmd) ->
  child = exec cmd, (error, stdout, stderr) ->
    console.log "exec error: #{error}" if error?

task 'build', ->
  run 'coffee -o lib -c src/*.coffee'
  console.log 'build ok'

task 'clean', ->
  run 'rm -f lib/*.js'
  run 'rm -f dist/lib/*.js'
  run 'rm -f dist/*.json'
  console.log 'clean ok'

task 'publish', ->
  run 'mkdir -p dist'
  run 'mkdir -p dist/lib'
  run 'cp lib/* dist/lib/'
  run 'cp package.json dist/'
  run 'cp README.md dist/'
  run 'sudo npm publish dist'
  console.log 'publish ok'
