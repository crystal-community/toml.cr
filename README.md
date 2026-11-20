# toml.cr

[![CI](https://github.com/crystal-community/toml.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/crystal-community/toml.cr/actions/workflows/ci.yml)

A [TOML](https://github.com/toml-lang/toml) parser for [Crystal](http://crystal-lang.org/), supporting [TOML 1.1](https://toml.io/en/v1.1.0).

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  toml:
    github: crystal-community/toml.cr
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

owner = toml["owner"].as_h
puts owner["name"] #=> "Lance Uppercut"
puts owner["dob"]  #=> "1979-05-27 07:32:00 UTC"
```

Offset date-times are returned as Crystal `Time` values. Local dates, times,
and date-times are returned as `TOML::LocalDate`, `TOML::LocalTime`, and
`TOML::LocalDateTime`. These values expose their calendar or clock components
without using the system time zone or the current date. Use `TOML::Any#raw`
to access them.

Offset date-times use the UTC range of Crystal's time type (years 1 through
9999). Leap seconds are unsupported.
