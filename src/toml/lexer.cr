# :nodoc:
class TOML::Lexer
  private DECIMAL   = /\A[+-]?(?:0|[1-9](?:_?[0-9])*+)\z/
  private BINARY    = /\A0b[01](?:_?[01])*+\z/
  private OCTAL     = /\A0o[0-7](?:_?[0-7])*+\z/
  private HEX       = /\A0x[0-9a-fA-F](?:_?[0-9a-fA-F])*+\z/
  private FLOAT     = /\A[+-]?(?:0|[1-9](?:_?[0-9])*+)(?:\.[0-9](?:_?[0-9])*+(?:[eE][+-]?[0-9](?:_?[0-9])*+)?|[eE][+-]?[0-9](?:_?[0-9])*+)\z/
  private DATE      = /\A([0-9]{4})-([0-9]{2})-([0-9]{2})\z/
  private DATE_TIME = /\A([0-9]{4})-([0-9]{2})-([0-9]{2})[Tt ]([^Tt ]+)\z/
  private CLOCK     = /\A([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.([0-9]+))?)?([Zz]|[+-][0-9]{2}:[0-9]{2})?\z/

  private PUNCTUATION = {
    '[' => :"[",
    ']' => :"]",
    '{' => :"{",
    '}' => :"}",
    '.' => :".",
    ',' => :",",
    '=' => :"=",
  }

  private SPECIAL_FLOATS = {
    "inf"  => Float64::INFINITY,
    "+inf" => Float64::INFINITY,
    "-inf" => -Float64::INFINITY,
    "nan"  => Float64::NAN,
    "+nan" => Float64::NAN,
    "-nan" => -Float64::NAN,
  }

  getter token : Token
  @current : Char?
  @lookahead : Char? = nil
  @line = 1
  @column = 1

  def self.new(string : String) : self
    new(IO::Memory.new(string))
  end

  def initialize(@input : IO) : Nil
    @token = Token.new
    @current = read_char
  end

  def next_token(*, value : Bool = false) : Token
    skip_horizontal_space
    skip_comment
    @token.line_number = @line
    @token.column_number = @column
    @token.multiline = false

    @token.type = case char = @current
                  when nil
                    :EOF
                  when '\n', '\r'
                    while newline?
                      consume_newline
                    end
                    :NEWLINE
                  when '"', '\''
                    consume_string(char)
                    :STRING
                  else
                    if punctuation = PUNCTUATION[char]?
                      advance
                      punctuation
                    elsif value
                      consume_value
                    elsif bare_key_char?(char)
                      @token.string_value = String.build do |io|
                        while (part = @current) && bare_key_char?(part)
                          io << part
                          advance
                        end
                      end
                      :KEY
                    else
                      invalid("unexpected character #{char.inspect}")
                    end
                  end
    @token
  end

  private def consume_value
    text = read_value_atom
    case
    when text == "true"
      :TRUE
    when text == "false"
      :FALSE
    when DECIMAL.matches?(text)
      integer(text, 10)
    when BINARY.matches?(text)
      integer(text.byte_slice(2), 2)
    when OCTAL.matches?(text)
      integer(text.byte_slice(2), 8)
    when HEX.matches?(text)
      integer(text.byte_slice(2), 16)
    when FLOAT.matches?(text)
      text = text.delete('_') if text.includes?('_')
      @token.float_value = parse_float(text)
      :FLOAT
    else
      if float = SPECIAL_FLOATS[text]?
        @token.float_value = float
        :FLOAT
      else
        @token.time_value = parse_temporal(text)
        :TIME
      end
    end
  end

  private def parse_float(text : String) : Float64
    if value = text.to_f64?
      return value if value.finite?
    else
      # Crystal versions differ on whether rounding to zero reports an error.
      # The grammar was already checked, so inspect the decimal magnitude to
      # tell underflow from overflow without going through another float parser.
      mantissa, _, exponent = text.partition(/[eE]/)
      if first_digit = mantissa.index(/[1-9]/)
        point = mantissa.index('.') || mantissa.bytesize
        shift = exponent.empty? ? 0_i64 : exponent.to_i64?
        if shift
          leading_power = point - first_digit - (first_digit < point ? 1 : 0)
          underflow = shift <= -324_i64 - leading_power
        else
          underflow = exponent.starts_with?('-')
        end
        invalid("float out of range") unless underflow
      end
      return text.starts_with?('-') ? -0.0 : 0.0
    end

    invalid("float out of range")
  end

  private def read_value_atom
    text = read_atom
    # A date may be followed by a single space and a time.
    if @current == ' ' && text.bytesize == 10 && DATE.matches?(text) && peek.try(&.ascii_number?)
      advance
      text = "#{text} #{read_atom}"
    end
    text
  end

  private def read_atom
    String.build do |io|
      while char = @current
        break if char.in?(' ', '\t', '\r', '\n', '#', ',', ']', '}')
        io << char
        advance
      end
    end
  end

  private def integer(text, base)
    @token.int_value = text.to_i64?(base, underscore: true) || invalid("integer out of range")
    :INT
  end

  private def parse_temporal(text) : TOML::Temporal
    if date_time = DATE_TIME.match(text)
      date = parse_date(date_time)
      clock, offset = parse_clock(date_time[4])
      if offset
        offset_time(date, clock, offset)
      else
        TOML::LocalDateTime.new(date, clock)
      end
    elsif date = DATE.match(text)
      parse_date(date)
    elsif text.includes?(':')
      clock, offset = parse_clock(text)
      invalid("a time without a date cannot have an offset") if offset
      clock
    else
      invalid("invalid value #{text.inspect}")
    end
  rescue error : ArgumentError
    invalid(error.message || "invalid date or time")
  end

  private def offset_time(date : TOML::LocalDate, clock : TOML::LocalTime, offset : Int32) : Time
    if date.year.zero?
      # A valid offset can advance December 31 into year 1. Use January 1
      # as the base date and account for the extra day in the subtraction.
      invalid("offset date-time precedes year 1 UTC") unless date.month == 12 && date.day == 31
      date = TOML::LocalDate.new(1, 1, 1)
      offset += 24 * 60
    end

    Time.utc(date.year, date.month, date.day, clock.hour, clock.minute, clock.second,
      nanosecond: clock.nanosecond) - offset.minutes
  end

  private def parse_date(match)
    TOML::LocalDate.new(match[1].to_i, match[2].to_i, match[3].to_i)
  end

  private def parse_clock(text)
    match = CLOCK.match(text) || invalid("invalid time #{text.inspect}")
    nanosecond = 0
    if fraction = match[4]?
      nanosecond = fraction.byte_slice(0, 9).ljust(9, '0').to_i
    end
    clock = TOML::LocalTime.new(match[1].to_i, match[2].to_i, match[3]?.try(&.to_i) || 0,
      nanosecond: nanosecond)
    offset = case zone = match[5]?
             when nil
               nil
             when "Z", "z"
               0
             else
               hour = zone.byte_slice(1, 2).to_i
               minute = zone.byte_slice(4, 2).to_i
               invalid("invalid UTC offset") unless hour < 24 && minute < 60
               (hour * 60 + minute) * (zone.starts_with?('-') ? -1 : 1)
             end
    {clock, offset}
  end

  private def consume_string(quote)
    advance
    multiline = false
    if @current == quote
      advance
      unless @current == quote
        @token.string_value = ""
        return
      end
      multiline = true
      advance
      consume_newline if newline?
    end
    @token.multiline = multiline
    @token.string_value = String.build do |io|
      loop do
        char = @current || invalid("unterminated string")
        if char == quote
          break if consume_string_quotes(io, quote, multiline)
        elsif char == '\\' && quote == '"'
          consume_string_escape(io, multiline)
        elsif multiline && newline?
          consume_newline
          io << '\n'
        else
          check_character(char)
          io << char
          advance
        end
      end
    end
  end

  private def consume_string_quotes(io, quote, multiline) : Bool
    advance
    return true unless multiline

    count = 1
    while @current == quote
      count += 1
      invalid("too many closing quotes") if count > 5
      advance
    end

    if count >= 3
      (count - 3).times { io << quote }
      true
    else
      count.times { io << quote }
      false
    end
  end

  private def consume_string_escape(io, multiline)
    advance
    if multiline && (newline? || @current.in?(' ', '\t'))
      skip_horizontal_space
      invalid("expected newline after string continuation") unless newline?
      while newline?
        consume_newline
        skip_horizontal_space
      end
    else
      io << consume_escape
    end
  end

  private def consume_escape : Char
    escaped = @current || invalid("unterminated string escape")
    advance
    case escaped
    when 'b'       then '\b'
    when 't'       then '\t'
    when 'n'       then '\n'
    when 'f'       then '\f'
    when 'r'       then '\r'
    when 'e'       then '\e'
    when 'x'       then consume_scalar(2)
    when 'u'       then consume_scalar(4)
    when 'U'       then consume_scalar(8)
    when '\\', '"' then escaped
    else                invalid("invalid string escape")
    end
  end

  private def consume_scalar(length)
    scalar = 0_u32
    length.times do
      char = @current
      digit = char.try(&.to_i?(16)) || invalid("expected hexadecimal digit in escape")
      scalar = scalar * 16 + digit.to_u32
      advance
    end
    invalid("invalid Unicode scalar in escape") unless unicode_scalar?(scalar)
    scalar.chr
  end

  private def bare_key_char?(char)
    char.ascii_alphanumeric? || char.in?('_', '-')
  end

  private def check_character(char)
    if (char < ' ' && char != '\t') || char == '\u007f'
      invalid("unexpected control character #{char.inspect}")
    end
  end

  private def skip_horizontal_space
    while @current.in?(' ', '\t')
      advance
    end
  end

  private def skip_comment
    return unless @current == '#'
    advance
    while (char = @current) && !newline?
      check_character(char)
      advance
    end
  end

  private def newline?
    @current.in?('\r', '\n')
  end

  private def consume_newline
    if @current == '\r'
      advance
      invalid("expected LF after CR") unless @current == '\n'
    end
    @line += 1
    @column = 0
    advance
  end

  private def peek
    @lookahead ||= read_char
  end

  private def advance
    @column += 1
    @current = @lookahead || read_char
    @lookahead = nil
  end

  # Decode raw UTF-8 bytes so IO encodings and older Crystal versions cannot
  # replace or accept malformed byte sequences before TOML validation.
  private def read_char
    first = @input.read_byte
    return if first.nil?
    return first.chr if first < 0x80

    remaining, minimum = case first
                         when 0xc2..0xdf then {1, 0x80}
                         when 0xe0..0xef then {2, 0x800}
                         when 0xf0..0xf4 then {3, 0x10000}
                         else                 invalid("invalid UTF-8 leading byte")
                         end

    scalar = first.to_u32 & (0x7f_u32 >> (remaining + 1))
    remaining.times do
      byte = @input.read_byte
      invalid("invalid UTF-8 continuation byte") unless byte && (byte & 0xc0) == 0x80
      scalar = (scalar << 6) | (byte & 0x3f)
    end

    invalid("invalid UTF-8 code point") unless scalar >= minimum && unicode_scalar?(scalar)
    scalar.chr
  end

  private def unicode_scalar?(scalar)
    scalar <= 0x10ffff && !(0xd800..0xdfff).includes?(scalar)
  end

  private def invalid(message) : NoReturn
    raise ParseException.new(message, @line, @column)
  end
end
