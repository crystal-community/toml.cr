require "./spec_helper"

private def it_parses(string, expected, file = __FILE__, line = __LINE__)
  it "parses #{string}", file, line do
    parser = Parser.new string
    actual = parser.parse
    actual.should eq(expected), file, line
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
  it_parses "", {} of String => Type
  it_parses "a = true", {"a": true}
  it_parses "a = false", {"a": false}
  it_parses "bare_key = false", {"bare_key": false}
  it_parses "bare-key = false", {"bare-key": false}

  it_parses %(
    hello = true
    world = false
    ),
    {"hello": true, "world": false}

  it_parses %(
    true = false
    false = true
    ),
    {"true": false, "false": true}

  it_parses "a = 987_654", {"a": 987_654}
  it_parses "a = 1.0", {"a": 1.0}
  it_parses %(a = "hello"), {"a": "hello"}
  it_parses "a = 1979-05-27T07:32:00Z", {"a": Time.new(1979, 5, 27, 7, 32, 0, kind: Time::Kind::Utc)}
  it_parses "a = 1979-05-27T00:32:00-07:00", {"a": Time.new(1979, 5, 27, 7, 32, 0, kind: Time::Kind::Utc)}

  it_parses "a = [1, 2, 3]", {"a": [1, 2, 3]}
  it_parses "a = [[[[]]]]", {"a": [[[[] of Type] of Type] of Type]}

  it_parses %(
    a = [
      1, 2, 3
    ]
    ), {"a": [1, 2, 3]}

  it_parses %(
    a = [
      1,
      2,
      3,
    ]
    ), {"a": [1, 2, 3]}

  it_parses %(
    [table]
    one = 1
    two = 2
    ),
    {"table": {"one": 1, "two": 2}}

  it_parses %(
    [table1]
    one = 1

    [table2]
    two = 2
    ),
    {"table1": {"one": 1}, "table2": {"two": 2}}

  it_parses %(
    [foo.bar.baz]
    one = 1
    ),
    {"foo": {"bar": {"baz": {"one": 1}}}}

  it_parses %(
    [ foo . bar . baz ]
    one = 1
    ),
    {"foo": {"bar": {"baz": {"one": 1}}}}

  it_parses %(
    [a.b]
    c = 1

    [a]
    d = 2
    ),
    {"a": {"b": {"c": 1}, "d": 2}}

  it_parses %(
    point = { x = 1, y = 2 }
    ),
    {"point": {"x": 1, "y": 2}}

  it_parses %(
    "foo" = 1
    ),
    {"foo": 1}

  it_parses %(
    [dog."tater.man"]
    type = "pug"
    ),
    {"dog": {"tater.man": {"type": "pug"}}}

  it_parses %(
    [foo]
    ),
    {"foo": Table.new}

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
      "products": [
        {"name": "Hammer", "sku": 738594937},
        Table.new,
        {"name": "Nail", "sku": 284758393, "color": "gray"},
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
      "fruit": [
        {
          "name":     "apple",
          "physical": {
            "color": "red",
            "shape": "round",
          },
        },
      ],
    }

  it_parses %(
    [[fruit.variety]]
    name = "red delicious"
    ),
    {"fruit": {"variety": [{"name": "red delicious"}]}}

  it_parses %(
    [[fruit]]
    name = "apple"

      [[fruit.variety]]
      name = "red delicious"
    ),
    {
      "fruit": [
        {
          "name":    "apple",
          "variety": [
            {"name": "red delicious"},
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
      "fruit": [
        {
          "name":     "apple",
          "physical": {
            "color": "red",
            "shape": "round",
          },
          "variety": [
            {"name": "red delicious"},
            {"name": "granny smith"},
          ],
        },
        {
          "name":    "banana",
          "variety": [
            {"name": "plantain"},
          ],
        },
      ],
    }

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
