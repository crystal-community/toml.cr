require "./spec_helper"

class TOML::Lexer
  def before_eq_symbol=(@before_eq_symbol : Bool)
  end
end

private def it_lexes(string, expected_type, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    lexer.before_eq_symbol = false
    token = lexer.next_token
    token.type.should eq(expected_type)
  end
end

private def it_lexes_key(string, value, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(:KEY)
    token.string_value.should eq(value)
  end
end

private def it_lexes_int(string, value, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(:INT)
    token.int_value.should eq(value)
  end
end

private def it_lexes_float(string, value, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    lexer.before_eq_symbol = false
    token = lexer.next_token
    token.type.should eq(:FLOAT)
    token.float_value.should eq(value)
  end
end

private def it_lexes_string(string, value, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    token = lexer.next_token
    token.type.should eq(:STRING)
    token.string_value.should eq(value)
  end
end

private def it_lexes_time(string, value, file = __FILE__, line = __LINE__)
  it "lexes #{string.inspect}", file, line do
    lexer = Lexer.new string
    lexer.before_eq_symbol = false
    token = lexer.next_token
    token.type.should eq(:TIME)
    token.time_value.should eq(value)
  end
end

private def it_raises(string, file = __FILE__, line = __LINE__)
  it "raises on lex #{string.inspect}", file, line do
    expect_raises ParseException do
      lexer = Lexer.new(string)
      lexer.before_eq_symbol = false
      while lexer.next_token.type != :EOF
        # Nothing
      end
    end
  end
end

describe Lexer do
  it_lexes "", :EOF
  it_lexes "[", :"["
  it_lexes "]", :"]"
  it_lexes "{", :"{"
  it_lexes "}", :"}"
  it_lexes ".", :"."
  it_lexes ",", :","
  it_lexes "=", :"="
  it_lexes "\n", :NEWLINE
  it_lexes "\n\n", :NEWLINE
  it_lexes "\r\n\r\n", :NEWLINE

  # Skips whitespace
  it_lexes "     [", :"["

  # Skips comments

  it_lexes_key "true", "true"
  it_lexes_key "false", "false"

  it_lexes_int "0", 0
  it_lexes_int "1", 1
  it_lexes_int "123456789", 123456789
  it_lexes_int "123_456_789", 123456789
  it_lexes_int "-123_456_789", -123456789
  it_lexes_int "+123_456_789", 123456789
  it_lexes_int "9223372036854775807", 9223372036854775807
  it_lexes_int "-9223372036854775807", -9223372036854775807

  # it_lexes_float "nan", Float64::NAN # Float64::NAN cannot be compared
  it_lexes "nan", :FLOAT
  it_lexes_float "inf", Float64::INFINITY
  it_lexes_float "12.34", 12.34
  it_lexes_float "0.123", 0.123
  it_lexes_float "1234.567", 1234.567
  it_lexes_float "0e1", 0
  it_lexes_float "0E1", 0
  it_lexes_float "0.1e1", 0.1e1
  it_lexes_float "0e+12", 0
  it_lexes_float "0e-12", 0
  it_lexes_float "1e2", 1e2
  it_lexes_float "1E2", 1e2
  it_lexes_float "1e+12", 1e12
  it_lexes_float "1.2e-3", 1.2e-3
  it_lexes_float "9.91343313498688", 9.91343313498688
  it_lexes_float "9.913_433_134_986_88", 9.91343313498688
  it_lexes_float "1.2e-3_4", 1.2e-34

  it_lexes_key "hello", "hello"
  it_lexes_key "truethy", "truethy"
  it_lexes_key "falsey", "falsey"

  it_lexes_string %("hello"), "hello"
  it_lexes_string %("hi \\b\\t\\n\\f\\r\\"\\\\ there"), "hi \b\t\n\f\r\"\\ there"
  it_lexes_string %("hi \\u1234 there"), "hi \u1234 there"
  it_lexes_string %("hi \\u00001234 there"), "hi \u1234 there"
  it_lexes_string %(""), ""
  it_lexes_string %("""hello"""), "hello"
  it_lexes_string %("""\nhello"""), "hello"
  it_lexes_string %("""\nhello\n  world\n"""), "hello\n  world\n"
  it_lexes_string %("""hi \\b\\t\\n\\f\\r\\"\\\\ there"""), "hi \b\t\n\f\r\"\\ there"
  it_lexes_string %("""\\

  The quick brown \\


  fox jumps over \\
    the lazy dog."""), "The quick brown fox jumps over the lazy dog."

  it_lexes_string %('hello'), "hello"
  it_lexes_string %('C:\\Users\\nodejs\\templates'), "C:\\Users\\nodejs\\templates"
  it_lexes_string %('''hello'''), "hello"
  it_lexes_string %('''\nhello  \n  world'''), "hello  \n  world"
  it_lexes_string %('''I don't need'''), "I don't need"

  it_lexes_time "1979-05-27T07:32:00Z", Time.utc(1979, 5, 27, 7, 32, 0)
  it_lexes_time "1979-05-27T07:32:00-07:30", Time.utc(1979, 5, 27, 15, 2, 0)
  it_lexes_time "1979-05-27T07:32:00+07:30", Time.utc(1979, 5, 27, 0, 2, 0)
  it_lexes_time "1979-05-27T07:32:00.999999-07:00",
    {% if Crystal::VERSION =~ /^0\.(\d|1\d|2[0-3])\./ %}
      Time.utc(1979, 5, 27, 14, 32, 0, 999)
    {% else %}
      Time.utc(1979, 5, 27, 14, 32, 0, nanosecond: 999999000)
    {% end %}

  it "lexes multinline basic string" do
    lexer = Lexer.new(%("""hello"""))

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.string_value.should eq("hello")

    lexer.next_token.type.should eq(:EOF)
  end

  it "lexes multinline basic string (2)" do
    lexer = Lexer.new(%("""hello\\\n"""))

    token = lexer.next_token
    token.type.should eq(:STRING)
    token.string_value.should eq("hello")

    lexer.next_token.type.should eq(:EOF)
  end

  it "skips comments" do
    lexer = Lexer.new " # hello\n[ # bye\n] # another"

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:"[")

    token = lexer.next_token
    token.type.should eq(:NEWLINE)

    token = lexer.next_token
    token.type.should eq(:"]")

    token = lexer.next_token
    token.type.should eq(:EOF)
  end

  it_raises "123__45"
  it_raises "0123"
  it_raises %("hello)
  it_raises %("\\u1")
  it_raises %("\\u12")
  it_raises %("\\u123")
  it_raises %("\\u12345")
  it_raises %("\\u123456")
  it_raises %("\\u1234567")
  it_raises %("hello\nworld")
  it_raises %(1.)
  it_raises %("\\xAg")
end
