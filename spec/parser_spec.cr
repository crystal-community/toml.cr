require "./spec_helper"

private def it_parses(string, expected, file = __FILE__, line = __LINE__)
  it "parses #{string}", file, line do
    parser = Parser.new string
    actual = parser.parse
    actual.should eq(expected), file: file, line: line
  end
end

private def it_parses_and_eq(string_a, string_b, file = __FILE__, line = __LINE__)
  it "parse result of #{string_a} and #{string_b} are equal", file, line do
    parser_a = Parser.new string_a
    result_a = parser_a.parse

    parser_b = Parser.new string_b
    result_b = parser_b.parse

    result_a.should eq(result_b), file, line
  end
end

private def it_raises(string, file = __FILE__, line = __LINE__)
  it "raises on parse #{string.inspect}", file, line do
    expect_raises ParseException do
      TOML.parse(string)
    end
  end
end

time_local = Time.local

describe Parser do
  it_parses "", {} of String => Type
  it_parses "a = true", {"a" => true}
  it_parses "a = false", {"a" => false}
  it_parses "bare_key = false", {"bare_key" => false}
  it_parses "bare-key = false", {"bare-key" => false}
  it_parses "1234 = false", {"1234" => false}

  it_parses %("" = false), {"" => false}
  it_parses %('' = false), {"" => false}
  it_parses %("127.0.0.1" = "value"), {"127.0.0.1" => "value"}
  it_parses %("character encoding" = "value"), {"character encoding" => "value"}
  it_parses %("ʎǝʞ" = "value"), {"ʎǝʞ" => "value"}
  it_parses %('key2' = "value"), {"key2" => "value"}
  it_parses %('quoted "value"' = "value"), { %(quoted "value") => "value" }
  it_parses %(quoted = 'Tom "Dubs" Preston-Werner'), {"quoted" => "Tom \"Dubs\" Preston-Werner"}

  it_parses %(
    hello = true
    world = false
    ),
    {"hello" => true, "world" => false}

  it_parses %(
    true = false
    false = true
    ),
    {"true" => false, "false" => true}

  it_parses "a = 987_654", {"a" => 987_654}
  it_parses "a = 1.0", {"a" => 1.0}

  it_parses %(
    a = inf
    b = +inf
    c = -inf
    ),
    {
      "a" => Float64::INFINITY,
      "b" => Float64::INFINITY,
      "c" => -Float64::INFINITY,
    }

  it_parses %(inf = 123), {"inf" => 123}
  it_parses %(nan = 123), {"nan" => 123}

  # Float64::NAN cannot be compared
  # it_parses %(
  #   a = nan
  #   b = +nan
  #   c = -nan
  #   ),
  #   {
  #     "a" => Float64::NAN,
  #     "b" => Float64::NAN,
  #     "c" => -Float64::NAN
  #   }

  it_parses %(a = "hello"), {"a" => "hello"}
  it_parses "a = 1979-05-27T07:32:00Z", {"a" => Time.utc(1979, 5, 27, 7, 32, 0)}
  it_parses "a = 1979-05-27T00:32:00+07:00", {"a" => Time.utc(1979, 5, 26, 17, 32, 0)}

  it_parses "a = 1979-05-27T00:32:00.999999-07:00",
    {"a" => Time.utc(1979, 5, 27, 7, 32, 0, nanosecond: 999999 * 1000)}

  it_parses "a = 1979-05-27T00:32:00.999999",
    {"a" => Time.local(1979, 5, 27, 0, 32, 0, nanosecond: 999999 * 1000)}

  it_parses "a = 1979-05-27 07:32:00Z", {"a" => Time.utc(1979, 5, 27, 7, 32, 0)}

  it_parses "a = 1979-05-27T00:32:00", {"a" => Time.local(1979, 5, 27, 0, 32, 0)}

  it_parses "a = 1979-05-27", {"a" => Time.local(1979, 5, 27)}

  it_parses "a = 1979-05-27  # comment", {"a" => Time.local(1979, 5, 27)}

  it_parses "a = 00:32:00",
    {"a" => Time.local(time_local.year, time_local.month, time_local.day, 0, 32, 0)}

  it_parses "a = 00:32:00.999999",
    {"a" => Time.local(
      time_local.year,
      time_local.month,
      time_local.day,
      0,
      32,
      0,
      nanosecond: 999999 * 1000)}

  it_parses %(a = [ [ 1, 2 ], ["a", "b", "c"] ]), {"a" => [[1, 2], ["a", "b", "c"]]}
  it_parses %(string_array = [ "all", 'strings', """are the same""", '''type''' ]),
    {"string_array" => ["all", "strings", "are the same", "type"]}
  it_parses %(integers2 = [
      1, 2, 3
    ]), {"integers2" => [1, 2, 3]}

  it_parses %(integers2 = [
    1,
    2,
  ]), {"integers2" => [1, 2]}
  it_parses "a = [1, 2, 3]", {"a" => [1, 2, 3]}
  it_parses "a = [[[[]]]]", {"a" => [[[[] of Type] of Type] of Type]}

  it_parses %(site."google.com" = true), {"site" => {"google.com" => true}}
  it_parses %(3.14159 = "pi"), {"3" => {"14159" => "pi"}}

  it_parses %(
    a = [
      1, 2, 3
    ]
    ), {"a" => [1, 2, 3]}

  it_parses %(
    a = [
      1,
      2,
      3,
    ]
    ), {"a" => [1, 2, 3]}

  it_parses %(
    [table]
    one = 1
    two = 2
    ),
    {"table" => {"one" => 1, "two" => 2}}

  it_parses %(
    [table1]
    one = 1

    [table2]
    two = 2
    ),
    {"table1" => {"one" => 1}, "table2" => {"two" => 2}}

  it_parses %(
      [dog."tater.man"]
      name = "pug"
    ),
    {"dog" => {"tater.man" => {"name" => "pug"}}}

  it_parses %(
      [dog."tater.man"]
      type.name = "pug"
    ),
    {"dog" => {"tater.man" => {"type" => {"name" => "pug"}}}}

  it_parses %(
    [foo.bar.baz]
    one = 1
    ),
    {"foo" => {"bar" => {"baz" => {"one" => 1}}}}

  it_parses %(
    [ foo . bar . baz ]
    one = 1
    ),
    {"foo" => {"bar" => {"baz" => {"one" => 1}}}}

  it_parses %(
    [a.b]
    c = 1

    [a]
    d = 2
    ),
    {"a" => {"b" => {"c" => 1}, "d" => 2}}

  it_parses %(
    point = { x = 1, y = 2 }
    ),
    {"point" => {"x" => 1, "y" => 2}}

  it_parses %(animal = { type.name = "pug" }), {"animal" => {"type" => {"name" => "pug"}}}

  it_parses %(
    "foo" = 1
    ),
    {"foo" => 1}

  it_parses %(
    [dog."tater.man"]
    type = "pug"
    ),
    {"dog" => {"tater.man" => {"type" => "pug"}}}

  it_parses %(
    [foo]
    ),
    {"foo" => Table.new}

  it_parses %(
    [[products]]
    name = "Hammer"
    sku = 738594937

    [[products]]

    [[products]]
    name = "Nail"
    sku = 284758393
    color = "gray"
    ),
    {
      "products" => [
        {"name" => "Hammer", "sku" => 738594937},
        Table.new,
        {"name" => "Nail", "sku" => 284758393, "color" => "gray"},
      ],
    }

  it_parses %(
    [[fruit]]
    name = "apple"

      [fruit.physical]
        color = "red"
        shape = "round"
    ),
    {
      "fruit" => [
        {
          "name"     => "apple",
          "physical" => {
            "color" => "red",
            "shape" => "round",
          },
        },
      ],
    }

  it_parses %(
    [[fruit.variety]]
    name = "red delicious"
    ),
    {"fruit" => {"variety" => [{"name" => "red delicious"}]}}

  it_parses %(
    [[fruit]]
    name = "apple"

      [[fruit.variety]]
      name = "red delicious"
    ),
    {
      "fruit" => [
        {
          "name"    => "apple",
          "variety" => [
            {"name" => "red delicious"},
          ],
        },
      ],
    }

  it_parses %(
    [[fruit]]
      name = "apple"

      [fruit.physical]
        color = "red"
        shape = "round"

      [[fruit.variety]]
        name = "red delicious"

      [[fruit.variety]]
        name = "granny smith"

    [[fruit]]
      name = "banana"

      [[fruit.variety]]
        name = "plantain"
    ),
    {
      "fruit" => [
        {
          "name"     => "apple",
          "physical" => {
            "color" => "red",
            "shape" => "round",
          },
          "variety" => [
            {"name" => "red delicious"},
            {"name" => "granny smith"},
          ],
        },
        {
          "name"    => "banana",
          "variety" => [
            {"name" => "plantain"},
          ],
        },
      ],
    }

  it_parses_and_eq %(name = { first = "Tom", last = "Preston-Werner" }),
    %([name]
      first = "Tom"
      last = "Preston-Werner")

  it_parses_and_eq %(point = { x = 1, y = 2 }),
    %([point]
      x = 1
      y = 2)

  it_parses_and_eq %(animal = { type.name = "pug" }),
    %([animal]
      type.name = "pug")

  it_raises %(a = [1, 2)
  it_raises %(a = [1,,2])
  it_raises %(a = [1\n2])
  it_raises %(point = { x = 1,, y = 2})
  it_raises %(point = { x = 1, )
  it_raises %([])
  it_raises %([a.])
  it_raises %([a..b])
  it_raises %([.b])
  it_raises %([.])
  it_raises %( = "no key name")

  it_raises %(
    [[fruit]]
      name = "apple"

      [[fruit.variety]]
        name = "red delicious"

      [fruit.variety]
        name = "granny smith"
    )

  it_raises %(
    [[fruit]]
      name = "apple"

      [fruit.variety]
        name = "granny smith"

      [[fruit.variety]]
        name = "red delicious"
    )

  it_raises "a = [1, false]"
  it_raises "a = [1, [2]]"

  it_raises %(
    a = 1
    a = 2
    )

  it_raises %(
    [a]
    [a]
    )

  it_raises %(
    [a]b]
    zyx = 42
  )
end
