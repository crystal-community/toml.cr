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

    result_a.should eq(result_b), file: file, line: line
  end
end

private def it_raises(string, file = __FILE__, line = __LINE__)
  it "raises on parse #{string.inspect}", file, line do
    expect_raises ParseException do
      TOML.parse(string)
    end
  end
end

describe Parser do
  it_parses "", {} of String => Any
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

  it_parses <<-TOML,
    hello = true
    world = false
    TOML
    {"hello" => true, "world" => false}

  it_parses <<-TOML,
    true = false
    false = true
    TOML
    {"true" => false, "false" => true}

  it_parses "a = 987_654", {"a" => 987_654}
  it_parses "a = 1.0", {"a" => 1.0}

  it "parses long fractional parts with and without separators" do
    compact = "1." + "1" * 200_000
    grouped = "1.1" + "_1" * 199_999
    TOML.parse("a = #{compact}")["a"].as_f.should eq(1.1111111111111112)
    TOML.parse("a = #{grouped}e+1")["a"].as_f.should eq(11.11111111111111)
  end

  it_parses <<-TOML,
    a = inf
    b = +inf
    c = -inf
    TOML
    {
      "a" => Float64::INFINITY,
      "b" => Float64::INFINITY,
      "c" => -Float64::INFINITY,
    }

  it_parses %(inf = 123), {"inf" => 123}
  it_parses %(nan = 123), {"nan" => 123}

  it "rounds floating-point underflow to signed zero" do
    TOML.parse("x = -1e-400")["x"].as_f.unsafe_as(UInt64).should eq(0x8000_0000_0000_0000_u64)
    TOML.parse("x = 2e-324")["x"].as_f.unsafe_as(UInt64).should eq(0_u64)
    TOML.parse("x = 4e-324")["x"].as_f.unsafe_as(UInt64).should eq(1_u64)
    TOML.parse("x = -1e-99999999999999999999")["x"].as_f.unsafe_as(UInt64).should eq(0x8000_0000_0000_0000_u64)
    TOML.parse("x = -0.#{"0" * 400}1")["x"].as_f.unsafe_as(UInt64).should eq(0x8000_0000_0000_0000_u64)
  end

  it "rejects overflow in finite float literals" do
    expect_raises(TOML::ParseException, /float out of range/) { TOML.parse("x = 1e400") }
    expect_raises(TOML::ParseException, /float out of range/) { TOML.parse("x = 1e99999999999999999999") }
  end

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

  it "applies the offset before checking the UTC year range" do
    TOML.parse("a = 0000-12-31T23:59:59.123456789-00:01")["a"].raw
      .should eq(Time.utc(1, 1, 1, 0, 0, 59, nanosecond: 123_456_789))
    TOML.parse("a = 0000-12-31T23:59:00-00:01")["a"].raw.should eq(Time.utc(1, 1, 1))

    expect_raises(TOML::ParseException) { TOML.parse("a = 0000-12-31T23:58:59-00:01") }
    expect_raises(TOML::ParseException) { TOML.parse("a = 0000-12-30T23:59:59-23:59") }
    expect_raises(TOML::ParseException) { TOML.parse("a = 9999-12-31T23:59:59-00:01") }
  end

  it_parses "a = 1979-05-27T00:32:00.999999-07:00",
    {"a" => Time.utc(1979, 5, 27, 7, 32, 0, nanosecond: 999999 * 1000)}

  it_parses "a = 1979-05-27T00:32:00.999999",
    {"a" => Any.new(LocalDateTime.new(LocalDate.new(1979, 5, 27), LocalTime.new(0, 32, nanosecond: 999_999_000)))}

  it_parses "a = 1979-05-27 07:32:00Z", {"a" => Time.utc(1979, 5, 27, 7, 32, 0)}

  it_parses "a = 1979-05-27T00:32:00",
    {"a" => Any.new(LocalDateTime.new(LocalDate.new(1979, 5, 27), LocalTime.new(0, 32)))}

  it_parses "a = 1979-05-27", {"a" => Any.new(LocalDate.new(1979, 5, 27))}

  it_parses "a = 1979-05-27  # comment", {"a" => Any.new(LocalDate.new(1979, 5, 27))}

  it_parses "a = 00:32:00", {"a" => Any.new(LocalTime.new(0, 32))}

  it_parses "a = 00:32:00.999999", {"a" => Any.new(LocalTime.new(0, 32, nanosecond: 999_999_000))}

  it_parses %(a = [ [ 1, 2 ], ["a", "b", "c"] ]), {"a" => [[1, 2], ["a", "b", "c"]]}
  it_parses %(string_array = [ "all", 'strings', """are the same""", '''type''' ]),
    {"string_array" => ["all", "strings", "are the same", "type"]}
  it_parses <<-TOML, {"integers2" => [1, 2, 3]}
    integers2 = [
      1, 2, 3
    ]
    TOML

  it_parses <<-TOML, {"integers2" => [1, 2]}
    integers2 = [
      1,
      2,
    ]
    TOML
  it_parses "a = [1, 2, 3]", {"a" => [1, 2, 3]}
  it_parses "a = [[[[]]]]", {"a" => Any.new([Any.new([Any.new([Any.new([] of Any)])])])}

  it_parses %(site."google.com" = true), {"site" => {"google.com" => true}}
  it_parses %(3.14159 = "pi"), {"3" => {"14159" => "pi"}}

  it_parses <<-TOML, {"a" => [1, 2, 3]}
    a = [
      1, 2, 3
    ]
    TOML

  it_parses <<-TOML, {"a" => [1, 2, 3]}
    a = [
      1,
      2,
      3,
    ]
    TOML

  it_parses <<-TOML,
    [table]
    one = 1
    two = 2
    TOML
    {"table" => {"one" => 1, "two" => 2}}

  it_parses <<-TOML,
    [table1]
    one = 1

    [table2]
    two = 2
    TOML
    {"table1" => Any.new({"one" => Any.new(1)}), "table2" => Any.new({"two" => Any.new(2)})}

  it_parses <<-TOML,
    [dog."tater.man"]
    name = "pug"
    TOML
    {"dog" => {"tater.man" => {"name" => "pug"}}}

  it_parses <<-TOML,
    [dog."tater.man"]
    type.name = "pug"
    TOML
    {"dog" => {"tater.man" => {"type" => {"name" => "pug"}}}}

  it_parses <<-TOML,
    [foo.bar.baz]
    one = 1
    TOML
    {"foo" => {"bar" => {"baz" => {"one" => 1}}}}

  it_parses <<-TOML,
    [ foo . bar . baz ]
    one = 1
    TOML
    {"foo" => {"bar" => {"baz" => {"one" => 1}}}}

  it_parses <<-TOML,
    [a.b]
    c = 1

    [a]
    d = 2
    TOML
    {"a" => {"b" => {"c" => 1}, "d" => 2}}

  it_parses <<-TOML,
    point = { x = 1, y = 2 }
    TOML
    {"point" => {"x" => 1, "y" => 2}}

  it_parses %(animal = { type.name = "pug" }), {"animal" => {"type" => {"name" => "pug"}}}

  it_parses <<-TOML,
    "foo" = 1
    TOML
    {"foo" => 1}

  it_parses <<-TOML,
    [dog."tater.man"]
    type = "pug"
    TOML
    {"dog" => {"tater.man" => {"type" => "pug"}}}

  it_parses <<-TOML,
    [foo]
    TOML
    {"foo" => Table.new}

  it_parses <<-TOML,
    [[products]]
    name = "Hammer"
    sku = 738594937

    [[products]]

    [[products]]
    name = "Nail"
    sku = 284758393
    color = "gray"
    TOML
    {
      "products" => [
        {"name" => "Hammer", "sku" => 738594937},
        Table.new,
        {"name" => "Nail", "sku" => 284758393, "color" => "gray"},
      ],
    }

  it_parses <<-TOML,
    [[fruit]]
    name = "apple"

      [fruit.physical]
        color = "red"
        shape = "round"
    TOML
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

  it_parses <<-TOML,
    [[fruit.variety]]
    name = "red delicious"
    TOML
    {"fruit" => {"variety" => [{"name" => "red delicious"}]}}

  it_parses <<-TOML,
    [[fruit]]
    name = "apple"

      [[fruit.variety]]
      name = "red delicious"
    TOML
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

  it_parses <<-TOML,
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
    TOML
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
    <<-TOML
      [name]
      first = "Tom"
      last = "Preston-Werner"
      TOML

  it_parses_and_eq %(point = { x = 1, y = 2 }),
    <<-TOML
      [point]
      x = 1
      y = 2
      TOML

  it_parses_and_eq %(animal = { type.name = "pug" }),
    <<-TOML
      [animal]
      type.name = "pug"
      TOML

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

  it_raises <<-TOML
    [[fruit]]
      name = "apple"

      [[fruit.variety]]
        name = "red delicious"

      [fruit.variety]
        name = "granny smith"
    TOML

  it_raises <<-TOML
    [[fruit]]
      name = "apple"

      [fruit.variety]
        name = "granny smith"

      [[fruit.variety]]
        name = "red delicious"
    TOML

  it_parses "a = [1, false]", {"a" => [1, false]}
  it_parses "a = [1, [2]]", {"a" => [1, [2]]}

  it_raises <<-TOML
    a = 1
    a = 2
    TOML

  it_raises <<-TOML
    [a]
    [a]
    TOML

  it_raises <<-TOML
    [a]b]
    zyx = 42
    TOML
end
