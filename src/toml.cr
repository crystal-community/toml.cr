# Main entry point for TOML parsing.
module TOML
  # A TOML Table. Just a convenience alias.
  alias Table = Hash(String, TOML::Any)

  # Parses a string.
  def self.parse(input : String) : TOML::Table
    Parser.parse(IO::Memory.new(input))
  end

  # Parses from an `IO`
  def self.parse(io : IO) : TOML::Table
    Parser.parse(io)
  end

  # Parses a file.
  def self.parse_file(filename) : TOML::Table
    parse File.read(filename)
  end
end

require "./toml/*"
