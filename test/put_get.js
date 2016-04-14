var test = require('tape');
var Store = require('../');

test('put and get on the same node', function(t) {
	t.plan(4);
	t.timeoutAfter(5000);

	var store = new Store();
	store.on('ready', function() {
		var value = 'test same';

		store.kvPut('key', value, function(err, key, n) {
			t.error(err);
			t.equal(key, 'key');

			store.kvGet('key', function(err, n, v) {
				t.error(err);
				t.equal(v, value);
				store.destroy();
			});
		});
	});
});

test('put and get on the different node', function(t) {
	t.plan(4);
	t.timeoutAfter(5000);
	var value = 'test different';

	var first_store = new Store({
		nodeIdFile: 'first_node.data'
	});
	first_store.on('ready', function() {
		first_store.kvPut('key', value, function(err, key, n) {
			t.error(err);
			t.equal(key, 'key');

			first_store.listen(6881);
		});
	});

	first_store.on('listening', function() {
		var second_store = new Store({
			nodes: [{
				host: '127.0.0.1',
				port: 6881
			}],
			nodeIdFile: 'second_node.data'
		});
		second_store.on('ready', function() {
			second_store.kvGet('key', 'utf8', function(err, n, v) {
				t.error(err);
				t.equal(v, value);
				second_store.destroy();
				first_store.destroy();
			});
		});
	});
});