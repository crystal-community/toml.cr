# :nodoc:
class TOML::Token
  property type : Symbol
  property? multiline : Bool

  property string_value : String
  property int_value : Int64
  property float_value : Float64
  property time_value : TOML::Temporal
  property line_number : Int32
  property column_number : Int32

  def initialize : Nil
    @type = :EOF
    @line_number = 0
    @column_number = 0
    @string_value = ""
    @int_value = 0_i64
    @float_value = 0.0
    @multiline = false
    @time_value = Time.unix(0)
  end

  def to_s(io : IO) : Nil
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
