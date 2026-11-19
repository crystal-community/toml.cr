module TOML
  # A calendar date without an associated timezone.
  struct LocalDate
    getter year : Int32
    getter month : Int32
    getter day : Int32

    def initialize(@year : Int32, @month : Int32, @day : Int32) : Nil
      # Crystal Time starts at year 1. Year 400 has the same leap-year
      # rules as year 0 in the proleptic Gregorian calendar.
      calendar_year = year.zero? ? 400 : year
      unless (0..9999).includes?(year) && (1..12).includes?(month) &&
             (1..Time.days_in_month(calendar_year, month)).includes?(day)
        raise ArgumentError.new("invalid calendar date")
      end
    end

    def to_s(io : IO) : Nil
      io.printf("%04d-%02d-%02d", year, month, day)
    end
  end

  # A time of day without an associated date or timezone.
  struct LocalTime
    getter hour : Int32
    getter minute : Int32
    getter second : Int32
    getter nanosecond : Int32

    def initialize(@hour : Int32, @minute : Int32, @second : Int32 = 0, *, @nanosecond : Int32 = 0) : Nil
      unless (0..23).includes?(hour) && (0..59).includes?(minute) &&
             (0..59).includes?(second) && (0..999_999_999).includes?(nanosecond)
        raise ArgumentError.new("invalid clock time")
      end
    end

    def to_s(io : IO) : Nil
      io.printf("%02d:%02d:%02d", hour, minute, second)
      unless nanosecond.zero?
        io << '.' << sprintf("%09d", nanosecond).rstrip('0')
      end
    end
  end

  # A calendar date and time of day without an associated timezone.
  struct LocalDateTime
    getter date : LocalDate
    getter time : LocalTime

    def initialize(@date : LocalDate, @time : LocalTime) : Nil
    end

    def to_s(io : IO) : Nil
      io << date << 'T' << time
    end
  end

  # The four date and time types supported by TOML.
  alias Temporal = Time | LocalDate | LocalTime | LocalDateTime
end
