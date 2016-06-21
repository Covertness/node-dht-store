events = require 'events'
fs = require 'fs'
crypto = require 'crypto'
krpc = require 'k-rpc'
LRU = require 'lru'
bencode = require 'bencode'
Type = require 'type-of-is'
debug = require('debug')('dht-store')

defaultOptions =
	# max items count
	maxItems: 10000
	# per item's ttl defaults to 1min
	ttl: 3 * 60 * 1000
	# the file that stored node id
	nodeIdFile: 'nodeid.data'
	# bootstrap nodes
	nodes: []

module.exports =
	class Store extends events.EventEmitter
		constructor: (opts) ->
			@options = opts || {}
			for o, v of defaultOptions
				if @options[o] == undefined
					@options[o] = v

			@destroyed = false
			@cache = new LRU {
				max: @options.maxItems
				maxAge: @options.ttl
			}

			fs.readFile @options.nodeIdFile, "utf-8", (_, data) =>
				if data
					idBuffer = new Buffer data, 'base64'
					if idBuffer.length == 20
						@options.id = idBuffer

				@rpc = krpc @options
				fs.writeFile @options.nodeIdFile, @rpc.id.toString 'base64'
				@nodeId = @rpc.id

				@rpc.on 'listening', @emit.bind(this, 'listening')
				@rpc.on 'warning', @emit.bind(this, 'warning')
				@rpc.on 'node', @emit.bind(this, 'node')

				@rpc.on 'query', (message, peer) =>
					@handleMessage message, peer

				@emit 'ready'

		listen: (port, cb) ->
			@rpc.bind port, cb

		kvPut: (key, value, cb) ->
			k = sha1 bencode.encode key

			@_kvPut k.toString('hex'), value

			message =
				q: 'kv_put'
				a:
					id: @nodeId
					k: k
					v: value
			closestNodes = @rpc.nodes.closest {id: k}

			debug 'put', k.toString('hex'), '->', value, 'in', closestNodes

			if closestNodes.length > 0
				@rpc.queryAll closestNodes, message, null, (err, n) =>
					cb null, key, n + 1
			else
				cb null, key, 1

		kvGet: (key, encoding, cb) ->
			k = sha1 bencode.encode key
			cb = cb ? encoding

			message =
				q: 'kv_get'
				a:
					id: @nodeId
					k: k

			item = @cache.get k.toString('hex')
			item = item ? {v: null, seq: 0}
			@rpc.closest k, message, (replyMessage, node) =>
				# TODO: cache closet nodes when value is undefined
				if replyMessage.r == undefined or replyMessage.r.v == undefined or replyMessage.r.seq == undefined
					return true

				if replyMessage.r.seq > item.seq
					item.v = replyMessage.r.v

				return true
			, (err, n) =>
				debug 'get', k.toString('hex'), '->', item.v, 'from', n, 'nodes'

				if Type(item.v, Buffer) and Type(encoding, String)
					item.v = item.v.toString encoding

				if item.v == null
					cb err, n, item.v
				else
					cb null, n + 1, item.v

		destroy: (cb) ->
			if @destroyed
				cb && cb()
				return

			@rpc.destroy(cb)

		bootstrap: (cb) ->
			message =
				q: 'find_node'
				a: 
					id: @nodeId
					target: @nodeId

			@rpc.populate @nodeId, message, cb

		handleMessage: (message, peer) ->
			method = message.q.toString()
			if message.a  == undefined
				return

			switch method
				when 'ping'
					@rpc.response peer, message, {id: @nodeId}
				when 'find_node'
					@handleFindNode message, peer
				when 'get_peers'
					@handleGetPeers message, peer
				when 'announce_peer'
					@rpc.response peer, message, {id: @nodeId}
				when 'kv_get'
					@handleKVGet message, peer
				when 'kv_put'
					@handleKVPut message, peer

		handleFindNode: (message, peer) ->
			target = message.a.target
			if target == undefined
				@rpc.error(peer, message, [203, '`find_node` missing required `a.target` field'])
				return

			closestNodes = @rpc.nodes.closest {id: target}
			@rpc.response peer, message, {id: @nodeId}, closestNodes

		handleGetPeers: (message, peer) ->
			infoHash = message.a.info_hash
			if infoHash == undefined
				@rpc.error(peer, message, [203, '`get_peers` missing required `a.info_hash` field'])
				return

			host = peer.address || peer.host
			r =
				id: @nodeId
				token: @generateToken host

			closestNodes = @rpc.nodes.closest {id: infoHash}
			@rpc.response peer, message, r, closestNodes

		handleKVGet: (message, peer) ->
			key = message.a.k
			if key == undefined
				@rpc.error(peer, message, [203, '`kv_get` missing required `a.key` field'])
				return

			item = @cache.get key.toString('hex')
			if item
				@rpc.response peer, message, {id: @nodeId, v: item.v, seq: item.seq}
			else
				closestNodes = @rpc.nodes.closest {id: key}
				@rpc.response peer, message, {id: @nodeId}, closestNodes

		handleKVPut: (message, peer) ->
			key = message.a.k
			value = message.a.v
			if key == undefined or value == undefined
				@rpc.error(peer, message, [203, '`kv_pet` missing required `a.key` & `a.value` field'])
				return

			keyStr = key.toString('hex')
			@_kvPut keyStr, value

			@rpc.response peer, message, {id: @nodeId}

		generateToken: (seedStr, secret) ->
			if secret == undefined
				secret = crypto.randomBytes(20)

			return crypto.createHash('sha1').update(new Buffer(seedStr, 'utf8')).update(secret).digest()

		_kvPut: (key, value) ->
			oldItem = @cache.get key
			if oldItem
				@cache.set key, {v: value, seq: oldItem.seq + 1}
			else
				@cache.set key, {v: value, seq: 1}

sha1 = (buf) -> return crypto.createHash('sha1').update(buf).digest()