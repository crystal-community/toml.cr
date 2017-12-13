# :nodoc:
class TOML::Lexer
  getter token

  def initialize(string)
    @reader = Char::Reader.new(string)
    @token = Token.new
    @line_number = 1
    @column_number = 1
    @io = IO::Memory.new
  end

  def next_token
    skip_whitespace
    skip_comment

    @token.line_number = @line_number
    @token.column_number = @column_number

    case current_char
    when '\0'
      @token.type = :EOF
    when '\r'
      if next_char == '\n'
        consume_newline
      else
        raise "expected '\\n' after '\\r'"
      end
    when '\n'
      consume_newline
    when '['
      next_char :"["
    when ']'
      next_char :"]"
    when '{'
      next_char :"{"
    when '}'
      next_char :"}"
    when '.'
      next_char :"."
    when ','
      next_char :","
    when '='
      next_char :"="
    when '0'
      consume_number leading_zero: true
    when '1'..'9'
      consume_number
    when '+'
      next_char
      consume_number
    when '-'
      next_char
      consume_number negative: true
    when '"'
      consume_string
    when '\''
      consume_literal_string
    else
      if key_part?(current_char)
        consume_key
      else
        unexpected_char
      end
    end

    @token
  end

  private def consume_newline
    @line_number += 1
    @column_number = 0
    while true
      case next_char
      when '\r'
        unless next_char == '\n'
          raise "expected '\\n' after '\\r'"
        end
      when '\n'
        # Nothing
      else
        break
      end
      @line_number += 1
      @column_number = 0
    end
    @token.line_number = @line_number
    @token.column_number = @column_number
    @token.type = :NEWLINE
  end

  private def consume_string
    @token.type = :STRING

    if next_char == '"'
      if next_char == '"'
        consume_multine_basic_string
      else
        @token.string_value = ""
      end
      return
    end

    consume_basic_string
  end

  private def consume_basic_string
    @io.clear

    while true
      case current_char
      when '"'
        next_char
        break
      when '\\'
        next_char
        consume_escape
      when '\0'
        raise "unterminated string literal"
      when '\n'
        raise "newline is not allowed in basic string"
      else
        @io << current_char
        next_char
      end
    end

    @token.string_value = @io.to_s
  end

  private def consume_multine_basic_string
    @io.clear

    if next_char == '\n'
      newline
      next_char
    end

    while true
      case current_char
      when '"'
        if next_char == '"'
          if next_char == '"'
            next_char
            break
          else
            @io << %("")
          end
        else
          @io << '"'
        end
        next_char
      when '\\'
        if next_char == '\n'
          newline
          next_char
          while true
            case current_char
            when ' ', '\t'
              next_char
            when '\n'
              newline
              next_char
            else
              break
            end
          end
        else
          consume_escape
        end
      when '\n'
        newline
        @io << '\n'
        next_char
      when '\0'
        raise "unterminated string literal"
      else
        @io << current_char
        next_char
      end
    end

    @token.string_value = @io.to_s
  end

  private def consume_literal_string
    @token.type = :STRING

    next_char
    start_pos = current_pos

    if current_char == '\''
      if next_char == '\''
        consume_multine_literal_string
        return
      else
        @token.string_value = ""
        return
      end
    end

    consume_basic_literal_string(start_pos)
  end

  private def consume_basic_literal_string(start_pos)
    while true
      case current_char
      when '\''
        @token.string_value = string_range(start_pos)
        next_char
        return
      when '\0'
        raise "unterminated string literal"
      else
        next_char
      end
    end
  end

  private def consume_multine_literal_string
    @io.clear

    if next_char == '\n'
      newline
      next_char
    end

    while true
      case current_char
      when '\''
        if next_char == '\''
          if next_char == '\''
            next_char
            break
          else
            @io << %('')
          end
        else
          @io << '\''
          @io << current_char
        end
      when '\n'
        newline
        @io << '\n'
      when '\0'
        raise "unterminated string literal"
      else
        @io << current_char
      end
      next_char
    end

    @token.string_value = @io.to_s
  end

  private def consume_escape
    case current_char
    when 'b'
      @io << '\b'
    when 't'
      @io << '\t'
    when 'n'
      @io << '\n'
    when 'f'
      @io << '\f'
    when 'r'
      @io << '\r'
    when 'u'
      @io << consume_unicode_scalar
      return
    when '\\', '\'', '"'
      @io << current_char
    else
      raise "unknown escape: \\#{current_char}"
    end

    next_char
  end

  private def consume_unicode_scalar
    value = 0

    4.times do |i|
      value = value * 16 + (next_char.to_i?(16) || raise("expecting hexadecimal number"))
    end

    if char_value = next_char.to_i?(16)
      value = value * 16 + char_value
      3.times do |i|
        value = value * 16 + (next_char.to_i?(16) || raise("expecting hexadecimal number"))
      end
      next_char
    end

    value.chr
  end

  private def skip_whitespace
    while current_char == ' ' || current_char == '\t'
      next_char
    end
  end

  private def skip_comment
    if current_char == '#'
      while true
        case next_char
        when '\0', '\n'
          break
        end
      end
    end
  end

  private def consume_number(negative = false, leading_zero = false)
    num = 0_i64
    num += current_char.to_i
    count = 1
    last_is_underscore = false
    has_underscore = false

    while true
      case next_char
      when '0'..'9'
        num = num * 10 + current_char.to_i
        last_is_underscore = false
        count += 1
      when '_'
        if last_is_underscore
          raise "double underscores in a number are now allowed"
        else
          last_is_underscore = true
          has_underscore = true
        end
      else
        break
      end
    end

    case current_char
    when '-'
      if count == 4 && !has_underscore && !negative
        return consume_time num
      else
        unexpected_char
      end
    when '.'
      return consume_float(negative, num)
    when 'e', 'E'
      return consume_exponent(negative, num)
    end

    if leading_zero && num != 0
      raise "numbers with leading zero are not allowed"
    end

    num *= -1 if negative

    @token.type = :INT
    @token.int_value = num
  end

  private def consume_float(negative, integer)
    divisor = 1_u64
    last_is_underscore = false
    next_char
    while true
      case current_char
      when '0'..'9'
        integer *= 10
        integer += current_char.to_i
        divisor *= 10
        next_char
        last_is_underscore = false
      when '_'
        if last_is_underscore
          raise "double underscores in a number are now allowed"
        else
          last_is_underscore = true
          next_char
        end
      else
        break
      end
    end

    if divisor == 1
      raise "expecting float decimal digit"
    end

    float = integer.to_f64 / divisor

    case current_char
    when 'e', 'E'
      consume_exponent(negative, float)
    else
      @token.type = :FLOAT
      @token.float_value = negative ? -float : float
    end
  end

  private def consume_exponent(negative, float)
    exponent = 0
    negative_exponent = false
    last_is_underscore = false

    case next_char
    when '+'
      next_char
    when '-'
      next_char
      negative_exponent = true
    end

    if '0' <= current_char <= '9'
      while true
        case current_char
        when '0'..'9'
          exponent *= 10
          exponent += (current_char.ord - '0'.ord)
          next_char
          last_is_underscore = false
        when '_'
          if last_is_underscore
            raise "double underscores in a number are now allowed"
          else
            last_is_underscore = true
            next_char
          end
        else
          break
        end
      end
    else
      unexpected_char
    end

    @token.type = :FLOAT

    exponent = -exponent if negative_exponent
    float *= (10_f64 ** exponent)
    @token.float_value = negative ? -float : float
  end

  private def consume_time(year)
    month = consume_time_component 2, "expected month digit"
    raise "expected '-'" unless next_char == '-'
    day = consume_time_component 2, "expected day digit"
    raise "expected 'T'" unless next_char == 'T'
    hour = consume_time_component 2, "expected hour digit"
    raise "expected ':'" unless next_char == ':'
    minute = consume_time_component 2, "expected minute digit"
    raise "expected ':'" unless next_char == ':'
    second = consume_time_component 2, "expected second digit"

    if next_char == '.'
      microseconds = consume_time_component 6, "expected microsecond digit"
      next_char
    else
      microseconds = 0
    end

    negative = false
    case current_char
    when 'Z'
      next_char
    when '+', '-'
      negative = current_char == '-'
      hour_offset = consume_time_component 2, "expected hour offset digit"
      raise "expected ':'" unless next_char == ':'
      minute_offset = consume_time_component 2, "expected minute offset digit"
      next_char
    else
      unexpected_char
    end

    time =
      {% if Crystal::VERSION =~ /^0\.(\d|1\d|2[0-3])\./ %}
        Time.new(year, month, day, hour, minute, second, microseconds / 1000, kind: Time::Kind::Utc) # 0.23.x or lower
      {% else %}
        Time.new(year, month, day, hour, minute, second, nanosecond: microseconds * 1000, kind: Time::Kind::Utc) # 0.24.x or higher
      {% end %}
    time += (negative ? hour_offset : -hour_offset).hours if hour_offset
    time += (negative ? minute_offset : -minute_offset).minutes if minute_offset

    @token.type = :TIME
    @token.time_value = time
  end

  private def consume_time_component(length, error_msg)
    value = 0
    length.times do
      value = 10 * value + (next_char.to_i? || raise(error_msg))
    end
    value
  end

  private def consume_key(start_pos = current_pos)
    while key_part?(current_char)
      next_char
    end
    @token.type = :KEY
    @token.string_value = string_range(start_pos)
  end

  private def key_part?(char)
    case char
    when 'a'..'z', 'A'..'Z', '0'..'9', '_', '-'
      true
    else
      false
    end
  end

  private def string_range(start_pos)
    string_range(start_pos, current_pos)
  end

  private def string_range(start_pos, end_pos)
    @reader.string.byte_slice(start_pos, end_pos - start_pos)
  end

  private def current_char
    @reader.current_char
  end

  private def next_char
    @column_number += 1
    @reader.next_char
  end

  private def next_char(token_type)
    @token.type = token_type
    next_char
  end

  private def current_pos
    @reader.pos
  end

  private def newline
    @token.line_number = @line_number += 1
    @token.column_number = @column_number = 0
  end

  private def unexpected_char(char = current_char)
    raise "unexpected char '#{char}'"
  end

  private def raise(msg)
    ::raise ParseException.new(msg, @line_number, @column_number)
  end
end
