# :nodoc:
class TOML::Token
  @time_value : Time

  property :type

  property :string_value
  property :int_value
  property :float_value
  property :time_value
  property :line_number
  property :column_number

  def initialize
    @type = :EOF
    @line_number = 0
    @column_number = 0
    @string_value = ""
    @int_value = 0_i64
    @float_value = 0.0
    @time_value =
      {% if Crystal::VERSION =~ /^0\.(\d|1\d|2[0-7])\./ %}
        Time.new(1, 1, 1)
      {% else %}
        Time.local # 2.8 deprecated `Time.new`
      {% end %}
  end

  def to_s(io)
    case @type
    when :KEY
      io << @string_value
    when :STRING
      @string_value.inspect(io)
    when :INT
      io << @int_value
    when :FLOAT
      io << @float_value
    else
      io << @type
    end
  end
end
