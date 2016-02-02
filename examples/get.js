var Store = require('../');

var store = new Store({
	bootstrap: true,
	nodes: [
		{host: '127.0.0.1', port: 6881}
	],
	nodeIdFile: 'node_get.data'
});

store.on('ready', function () {
	console.log('the store is ready');

	store.kvGet('key', 'utf8', function (err, n, value) {
		if (err || value === null) {
			console.log('err:', err, 'value:', value);
			return;
		}

		console.log('value:', value);
	});
});