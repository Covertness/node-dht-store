# node-dht-store
A key/value store based on DHT.

## Features
- use custom keys differ from [BEP 44](http://bittorrent.org/beps/bep_0044.html)
- support ttl

## Install
```bash
$ npm install dht-store
```

## Example
```js
var Store = require('dht-store');

var store = new Store();
store.on('ready', function() {
    store.kvPut('key', 'test', function(err, key, n) {
        if (err) {
            console.log('err:', err);
            store.destroy();
            return;
        }

        store.kvGet('key', function(err, v) {
            console.log('value:', v);
            store.destroy();
        });
    });
});
```
More examples can be found in the folder [examples](examples/).

## Build from source
```bash
$ make init
$ make build
```

## Test
```bash
$ make test
```