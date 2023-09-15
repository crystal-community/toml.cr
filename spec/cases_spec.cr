require "./spec_helper"
require "json"

private def compare(toml : Bool, json : JSON::Any)
  json["type"].should eq("bool")
  json["value"].to_s.should eq(toml.to_s)
end

private def compare(toml : Int64, json : JSON::Any)
  json["type"].should eq("integer")
  json["value"].to_s.to_i64.should eq(toml)
end

private def compare(toml : Float64, json : JSON::Any)
  json["type"].should eq("float")
  json["value"].to_s.to_f.should eq(toml)
end

private def compare(toml : String, json : JSON::Any)
  json["type"].should eq("string")
  json["value"].should eq(toml)
end

private def compare(toml : Time, json : JSON::Any)
  json["type"].should eq("datetime")
  json["value"].should eq(toml.to_s("%Y-%m-%dT%H:%M:%SZ"))
end

private def compare(toml_hash : Hash, json : JSON::Any)
  if hash = json.as_h?
    compare toml_hash, hash
  else
    fail "comparison failed: #{toml_hash} vs. #{json}"
  end
end

private def compare(toml_hash : Hash, json_hash : Hash)
  if toml_hash.keys.to_set != json_hash.keys.to_set
    fail "keys are different"
  end

  toml_hash.each do |key, toml_value|
    json_value = json_hash[key]
    compare toml_value.raw, json_value
  end
end

private def compare(toml_array : Array, json : JSON::Any)
  if json.raw.is_a?(Array)
    compare toml_array, json.as_a
  elsif json.raw.is_a?(Hash) && json["type"]? == "array" && (value = json["value"]?)
    compare toml_array, value.as_a
  else
    fail "comparison failed: #{toml_array} vs. #{json}"
  end
end

private def compare(toml_array : Array, json_array : Array)
  if toml_array.size != json_array.size
    fail "array sizes differ"
  end

  toml_array.zip(json_array) do |toml_value, json_value|
    compare toml_value.raw, json_value
  end
end

private def compare(toml_value : Array, json_hash : Hash)
  json_hash["type"].should eq("array")
  json_value = json_hash["value"].as_a
  compare toml_value, json_value
end

private def compare(toml_value, json_value)
  fail "comparison failed: #{toml_value} vs. #{json_value}"
end

describe TOML do
  files = Dir["#{__DIR__}/cases/valid/*.toml"]
  files.each do |file|
    it "parses valid case '#{file}'" do
      toml = TOML.parse_file(file)
      json = JSON.parse(File.read("#{file[0..-5]}json")).raw

      compare toml, json.as(Hash)
    end
  end

  files = Dir["#{__DIR__}/cases/invalid/*.toml"]
  files.each do |file|
    it "raises on invalid case '#{file}'" do
      expect_raises ParseException do
        TOML.parse_file file
      end
    end
  end
end
