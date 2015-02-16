module TOML
  # Represents a possible type inside a TOML Array or TOML Hash (Table)
  alias Type = Bool | Int64 | Float64 | String | Time | Array(Type) | Hash(String, Type)

  # A TOML Table. Just a convenience alias.
  alias Table = Hash(String, Type)

  def self.parse(string)
    Parser.parse(string)
  end

  # Parses a file, returning a `TOML::Table`.
  def self.parse_file(filename)
    parse File.read(filename)
  end
end

require "./toml/*"
