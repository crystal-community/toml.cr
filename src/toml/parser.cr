# :nodoc:
class TOML::Parser
  def self.parse(string)
    new(string).parse
  end

  def initialize(string)
    @lexer = Lexer.new(string)
    @names = [] of String
    next_token
  end

  def parse
    root_table = Table.new
    table = root_table

    while true
      case token.type
      when :EOF
        break
      when :NEWLINE
        next_token
      when :KEY, :INT, :STRING
        parse_key_value(table)
        case token.type
        when :NEWLINE
          next_token
        when :EOF
          # Nothing
        else
          unexpected_token
        end
      when :"["
        table = parse_table_header(root_table)
      else
        unexpected_token
      end
    end

    root_table
  end

  private def parse_key_value(root_table)
    table, key = parse_key(root_table) do |table, name, has_more_names|
      existing_value = table[name]?
      if existing_value
        case existing_value
        when Hash
          if !has_more_names && existing_value.empty?
            raise "table #{@names.join '.'} already defined"
          end

          table = existing_value
        when Array
          unless has_more_names
            raise "expected #{@names.join '.'} to be a Table, not #{existing_value}"
          end

          if last_element = existing_value.last?
            if last_element.is_a?(Hash)
              table = last_element
            else
              raise "expected #{@names.join '.'} to be a Table of Array, not #{existing_value}"
            end
          else
            table = Table.new
            existing_value << table
          end
        else
          raise "expected #{@names.join '.'} to be a Table, not #{existing_value}"
        end
      else
        table = table[name] = Table.new
      end

      table
    end

    check :"="
    next_token

    if table.has_key?(key)
      raise "duplicated key: '#{key}'"
    end

    table[key] = parse_value
  end

  private def parse_key(table, double_ending = false)
    @names.clear

    while true
      case token.type
      when :KEY, :STRING, :INT
        if token.type == :INT
          name = token.int_value.to_s
        else
          name = token.string_value
        end
        @names << name
        next_token

        has_more_names = token.type == :"."

        unless has_more_names
          return {table, name}
        end

        table = yield table, name, has_more_names

        case token.type
        when :"."
          next_token
          unexpected_token if token.type == :"."
        end
      else
        unexpected_token
      end
    end

    unexpected_token
  end

  private def parse_key_value_after_key(table)
    parse_key_value(table)
  end

  private def parse_value
    case token.type
    when :KEY
      case token.string_value
      when "true"
        true.tap { next_token }
      when "false"
        false.tap { next_token }
      else
        unexpected_token
      end
    when :INT
      token.int_value.tap { next_token }
    when :FLOAT
      token.float_value.tap { next_token }
    when :STRING
      token.string_value.tap { next_token }
    when :TIME
      token.time_value.tap { next_token }
    when :"["
      parse_array
    when :"{"
      parse_inline_table
    else
      unexpected_token
    end
  end

  private def parse_table_header(root_table)
    next_token

    if token.type == :"["
      next_token
      return parse_array_table_header(root_table)
    end

    parse_header(root_table) do |table, name, has_more_names|
      existing_value = table[name]?
      if existing_value
        case existing_value
        when Hash
          if !has_more_names && existing_value.empty?
            raise "table #{@names.join '.'} already defined"
          end

          table = existing_value
        when Array
          unless has_more_names
            raise "expected #{@names.join '.'} to be a Table, not #{existing_value}"
          end

          if last_element = existing_value.last?
            if last_element.is_a?(Hash)
              table = last_element
            else
              raise "expected #{@names.join '.'} to be a Table of Array, not #{existing_value}"
            end
          else
            table = Table.new
            existing_value << table
          end
        else
          raise "expected #{@names.join '.'} to be a Table, not #{existing_value}"
        end
      else
        table = table[name] = Table.new
      end

      table
    end
  end

  private def parse_array_table_header(root_table)
    parse_header(root_table, double_ending: true) do |table, name, has_more_names|
      existing_value = table[name]?
      if existing_value
        case existing_value
        when Array
          array = existing_value
          if array.empty? || !has_more_names
            table = Table.new
            array << table
          else
            last = array.last
            unless last.is_a?(Table)
              raise "expected #{@names.join '.'} to be an Array of Table, not #{existing_value}"
            end

            table = last
          end
        when Hash
          if has_more_names
            table = existing_value
          else
            raise "expected #{@names.join '.'} to be an Array, not #{existing_value}"
          end
        else
          raise "expected #{@names.join '.'} to be an Array, not #{existing_value}"
        end
      else
        if has_more_names
          table = table[name] = Table.new
        else
          array = table[name] = [] of Type
          table = Table.new
          array << table
        end
      end
      table
    end
  end

  private def parse_header(table, double_ending = false)
    @names.clear

    while true
      case token.type
      when :KEY, :STRING, :INT
        if token.type == :INT
          name = token.int_value.to_s
        else
          name = token.string_value
        end
        @names << name
        next_token

        has_more_names = token.type == :"."

        table = yield table, name, has_more_names

        case token.type
        when :"."
          next_token
          unexpected_token if token.type == :"."
        when :"]"
          next_token

          if double_ending
            check :"]"
            next_token
          end

          case token.type
          when :EOF, :NEWLINE
            return table
          else
            unexpected_token
          end
        end
      else
        unexpected_token
      end
    end

    unexpected_token
  end

  private def parse_array
    next_token

    ary = [] of Type
    previous_value = nil

    while true
      case token.type
      when :NEWLINE
        next_token
        next
      when :"]"
        next_token
        break
      else
        new_value = parse_value
        ary << new_value

        if previous_value && previous_value.class != new_value.class
          raise "cannot mix types in array"
        end

        previous_value = new_value

        case token.type
        when :NEWLINE
          next_token
          check :"]"
          next_token
          break
        when :","
          next_token
        when :"]"
          next_token
          break
        else
          raise "expected ',', ']' or newline, not #{token}"
        end
      end
    end

    ary
  end

  private def parse_inline_table
    next_token

    table = Table.new
    while true
      case token.type
      when :KEY, :STRING, :INT
        parse_key_value_after_key(table)

        if token.type == :","
          next_token
        end

        if token.type == :"}"
          next_token
          break
        end
      else
        unexpected_token
      end
    end
    table
  end

  private delegate token, next_token, to: @lexer

  private def check(token_type)
    raise "expecting token '#{token_type}', not '#{token}'" unless token_type == token.type
  end

  private def raise(msg)
    ::raise ParseException.new(msg, token.line_number, token.column_number)
  end

  private def unexpected_token
    raise "unexpected token '#{token}'"
  end
end
