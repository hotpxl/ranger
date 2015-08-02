#!/usr/bin/env coffee
fs = require 'fs'
Q = require 'q'
_ = require 'lodash'
request = require 'request'
sexpression = require 'sexpression'

rirLocation = 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'

requestAsync = (url) ->
  deferred = Q.defer()
  request url, (error, response, body) ->
    if error or response.statusCode != 200
      deferred.reject error
    else
      deferred.resolve body
  deferred.promise

cached = (f) ->
  cache = {} if not cache?
  cache[f] = null
  ->
    if cache[f]
      Q cache[f]
    else
      f()
      .then (data) ->
        cache[f] = data
        cache[f]

getRirStats = cached ->
  requestAsync rirLocation
  .then (data) ->
    lines = data.trim().split '\n'
    ret = []
    _.map lines, (line) ->
      # Skip comments.
      if line.length == 0 or line[0] == '#'
        return
      parts = line.split '|'
      # Skip non IPv4 entries.
      if parts[1] == '*' or parts[2] != 'ipv4'
        return
      mask = 32 - Math.round(Math.log2(parseInt(parts[4])))
      ret.push
        loc: parts[1]
        net: "#{parts[3]}/#{mask}"
    ret

getAllLoc = cached ->
  getRirStats()
  .then (data) ->
    loc = _.uniq _.sortBy(_.map(data, 'loc')), true
    loc

getUserConfig = (userConfig) ->
  Q.nfcall fs.readFile, userConfig, encoding: 'ascii'
  .then (data) ->
    obj = sexpression.parse data
    ret = {}
    _.map obj, (entry) ->
      i = entry[0].name
      if typeof(entry[1]) == 'string'
        ret[i] = entry[1]
      else
        ret[i] = entry[1].name
    ret

getUserConfigClassified = (userConfig) ->
  getUserConfig userConfig
  .then (config) ->
    getAllLoc()
    .then (allLoc) ->
      ret =
        loc: {}
        default: null
        extra: {}
      _.map config, (v, k) ->
        if k in allLoc
          ret.loc[k] = v
        else if k == '*'
          ret.default = v
        else
          ret.extra[k] = v
      ret

generateRoutingTable = (classifiedConfig) ->
  getRirStats()
  .then (rirStats) ->
    ret = []
    _.map rirStats, (entry) ->
      if classifiedConfig.loc[entry.loc]?
        ret.push
          dest: entry.net
          gateway: classifiedConfig.loc[entry.loc]
      else if classifiedConfig.default?
        ret.push
          dest: entry.net
          gateway: classifiedConfig.default
    _.map classifiedConfig.extra, (v, k) ->
      ret.push
        dest: k
        gateway: v
    ret

writeRoutingTable = (del, table) ->
  if del
    action = 'del'
  else
    action = 'add'
  ret = ['ip -batch - <<EOF']
  _.map table, (entry) ->
    ret.push "route #{action} #{entry.dest} #{entry.gateway}"
  ret.push 'EOF'
  ret.join '\n'

if require.main == module
  parser = new (require('argparse').ArgumentParser)(
    descirption: 'generate routing table'
  )
  parser.addArgument ['-d', '--del'],
    help: 'delete routing table'
    action: 'storeTrue'
  parser.addArgument ['-c', '--config'],
    help: 'configuration file for gateways'
    required: true
    action: 'store'
  args = parser.parseArgs()
  getUserConfigClassified args.config
  .then (u) ->
    generateRoutingTable u
  .then (res) ->
    d = writeRoutingTable args.del, res
    console.log d
  .done()

