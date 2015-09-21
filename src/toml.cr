# Main entry point for TOML parsing.
module TOML
  # Represents a possible type inside a TOML Array or TOML Hash (Table)
  alias Type = Bool | Int64 | Float64 | String | Time | Array(Type) | Hash(String, Type)

  # A TOML Table. Just a convenience alias.
  alias Table = Hash(String, Type)

  # Parses a string.
  def self.parse(string) : TOML::Table
    Parser.parse(string)
  end

  # Parses a file.
  def self.parse_file(filename) : TOML::Table
    parse File.read(filename)
  end
end

require "./toml/*"
