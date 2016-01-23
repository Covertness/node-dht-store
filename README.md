# node-dht-store
[![Build Status](https://travis-ci.org/Covertness/node-dht-store.svg?branch=master)](https://travis-ci.org/Covertness/node-dht-store)
[![Coverage Status](https://coveralls.io/repos/Covertness/node-dht-store/badge.svg)](https://coveralls.io/r/Covertness/node-dht-store)
[![npm version](https://badge.fury.io/js/dht-store.svg)](http://badge.fury.io/js/dht-store)
![Downloads](https://img.shields.io/npm/dm/dht-store.svg?style=flat)

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