# crystal-toml

[![Build Status](https://travis-ci.org/manastech/crystal-toml.png)](https://travis-ci.org/manastech/crystal-toml) [![docrystal.org](http://docrystal.org/badge.svg?style=round)](http://docrystal.org/github.com/manastech/crystal-toml>)

A [TOML](https://github.com/toml-lang/toml) parser for [Crystal](http://crystal-lang.org/), compliant with the v0.4.0 version of TOML.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystal-toml:
    github: manastech/crystal-toml
    branch: master
```

### Usage

```crystal
require "toml"

toml_string = %(
  title = "TOML Example"

  [owner]
  name = "Lance Uppercut"
  dob = 1979-05-27T07:32:00Z
)

toml = TOML.parse(toml_string)
puts toml["title"] #=> "TOML Example"

owner = toml["owner"] as Hash
puts owner["name"] #=> "Lance Uppercut"
puts owner["dob"]  #=> "1979-05-27 07:32:00 UTC"
```
