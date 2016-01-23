var Store = require('../');

var store = new Store();

store.on('ready', function () {
	console.log('the store is ready');

	store.listen(6881);
});

store.on('listening', function () {
	store.kvPut('key', 'test222', function (err, key, n) {
		if (err) {
			console.log('err:', err);
			return;
		}

		console.log('put success! key:', key, 'nodesNum:', n);
		
		store.kvGet('key', function (err, value) {
			console.log('value:', value);
		});
	});
});