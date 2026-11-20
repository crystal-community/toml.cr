# :nodoc:
class TOML::Parser
  private enum TableKind
    Implicit
    Header
    Dotted
    Inline
  end

  # The output keeps its public Hash/Array representation. Track how containers
  # were declared by identity while parsing, since their contents can change.
  @table_kinds = Hash(Table, TableKind).new.compare_by_identity
  @arrays_of_tables = Set(Array(Any)).new.compare_by_identity

  def self.parse(input : String | IO) : Table
    new(input).parse
  end

  def self.new(string : String) : self
    new(IO::Memory.new(string))
  end

  def initialize(io : IO) : Nil
    @lexer = Lexer.new(io)
    next_token
  end

  def parse : Table
    root = Table.new
    table = root

    until token.type == :EOF
      if token.type == :NEWLINE
        next_token
        next
      end

      if token.type == :"["
        table = parse_header(root)
      else
        parse_key_value(table)
      end

      unexpected_token unless token.type.in?(:EOF, :NEWLINE)
    end

    root
  end

  private def parse_key_value(table)
    key = parse_key do |name|
      if entry = table[name]?
        child = entry.as_h?
        unless child && @table_kinds[child].in?(TableKind::Implicit, TableKind::Dotted)
          invalid("cannot extend #{name.inspect} with a dotted key")
        end
        @table_kinds[child] = TableKind::Dotted
        table = child
      else
        table = add_table(table, name, TableKind::Dotted)
      end
    end

    check :"="
    invalid("duplicate key #{key.inspect}") if table.has_key?(key)
    next_token(value: true)
    table[key] = parse_value
  end

  private def parse_key(&)
    loop do
      key_token = token.type == :KEY || (token.type == :STRING && !token.multiline?)
      unexpected_token unless key_token
      name = token.string_value
      next_token
      return name unless token.type == :"."

      yield name
      next_token
    end
  end

  private def parse_header(table)
    opening_column = token.column_number
    next_token
    array = token.type == :"[" && token.column_number == opening_column + 1
    next_token if array

    key = parse_key do |name|
      table = header_parent(table, name)
    end

    check :"]"
    closing_column = token.column_number
    next_token
    if array
      unless token.type == :"]" && token.column_number == closing_column + 1
        invalid("expected adjacent closing brackets")
      end
      next_token
      append_table(table, key)
    elsif entry = table[key]?
      child = entry.as_h?
      unless child && @table_kinds[child].implicit?
        invalid("cannot redefine table #{key.inspect}")
      end
      @table_kinds[child] = TableKind::Header
      child
    else
      add_table(table, key, TableKind::Header)
    end
  end

  private def header_parent(table, name)
    entry = table[name]?
    return add_table(table, name, TableKind::Implicit) unless entry

    if child = entry.as_h?
      return child unless @table_kinds[child].inline?
    elsif array = entry.as_a?
      return array.last.as_h if @arrays_of_tables.includes?(array)
    end

    invalid("cannot use #{name.inspect} as a parent table")
  end

  private def append_table(table, key)
    if entry = table[key]?
      array = entry.as_a?
      unless array && @arrays_of_tables.includes?(array)
        invalid("cannot redefine #{key.inspect} as an array of tables")
      end
    else
      array = [] of Any
      table[key] = Any.new(array)
      @arrays_of_tables.add(array)
    end

    child = new_table(TableKind::Header)
    array << Any.new(child)
    child
  end

  private def new_table(kind)
    Table.new.tap { |table| @table_kinds[table] = kind }
  end

  private def add_table(parent, name, kind)
    new_table(kind).tap { |table| parent[name] = Any.new(table) }
  end

  private def parse_value : Any
    value = case token.type
            when :TRUE
              true.tap { next_token }
            when :FALSE
              false.tap { next_token }
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
    Any.new(value)
  end

  private def parse_array
    array = [] of Any
    next_token(value: true)
    skip_newlines(value: true)

    until token.type == :"]"
      array << parse_value
      skip_newlines
      break if token.type == :"]"

      check :","
      next_token(value: true)
      skip_newlines(value: true)
    end

    next_token
    array
  end

  private def parse_inline_table
    table = new_table(TableKind::Inline)
    next_token
    skip_newlines

    until token.type == :"}"
      parse_key_value(table)
      skip_newlines
      break if token.type == :"}"

      check :","
      next_token
      skip_newlines
    end

    next_token
    table
  end

  private def skip_newlines(*, value : Bool = false)
    while token.type == :NEWLINE
      next_token(value: value)
    end
  end

  private delegate token, next_token, to: @lexer

  private def check(type)
    invalid("expected #{type}, got #{token}") unless token.type == type
  end

  private def unexpected_token : NoReturn
    invalid("unexpected token #{token}")
  end

  private def invalid(message) : NoReturn
    raise ParseException.new(message, token.line_number, token.column_number)
  end
end
