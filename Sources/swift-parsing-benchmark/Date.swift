import Benchmark
import Foundation
import Parsing

/*
 This benchmarks implements an [RFC-3339-compliant](https://www.ietf.org/rfc/rfc3339.txt) date
 parser in a relatively naive way and pits it against `DateFormatter` and `ISO8601DateFormatter`.

     name                      time         std        iterations
     ------------------------------------------------------------
     Date.Parser               12776.000 ns ±  55.45 %      99633
     Date.DateFormatter        41406.000 ns ±  31.12 %      31546
     Date.ISO8601DateFormatter 56481.000 ns ±  30.28 %      23268

 Not only is the parser faster than both formatters, it is also more flexible. It will parse
 fractional seconds and time zone offsets automatically, whereas each formatter must be more
 explicit in the format it will parse.
 */

// MARK: - Parser

private typealias Input = Substring.UTF8View

private let dateTime = OneOf {
  offsetDateTime
  localDateTime
  localDate
  localTime
}

private let dateFullyear = Prefix<Input>(4).pipe {
  Int.parser()
  End()
}

private let dateMonth = Prefix<Input>(2).pipe {
  Int.parser()
  End()
}

private let dateMday = Prefix<Input>(2).pipe {
  Int.parser()
  End()
}

private let timeDelim = OneOf {
  "T".utf8
  "t".utf8
  " ".utf8
}

private let timeHour = Prefix<Input>(2).pipe {
  Int.parser()
  End()
}

private let timeMinute = Prefix<Input>(2).pipe {
  Int.parser()
  End()
}

private let timeSecond = Prefix<Input>(2).pipe {
  Int.parser()
  End()
}

private let nanoSecfrac = Prefix<Input>
  .init(while: (.init(ascii: "0") ... .init(ascii: "9")).contains)
  .map { $0.prefix(9) }

private let timeSecfrac = Parse {
  ".".utf8
  nanoSecfrac
}
.compactMap { n in
  Int(String(decoding: n, as: UTF8.self))
    .map { $0 * Int(pow(10, 9 - Double(n.count))) }
}

private let timeNumoffset = Parse {
  OneOf {
    "+".utf8.map { 1 }
    "-".utf8.map { -1 }
  }
  timeHour
  ":".utf8
  timeMinute
}

private let timeOffset = OneOf {
  "Z".utf8.map { (/*sign: */1, /*minute: */0, /*second: */0) }
  timeNumoffset
}
.compactMap { TimeZone(secondsFromGMT: $0 * ($1 * 60 + $2)) }

private let partialTime = Parse {
  timeHour
  ":".utf8
  timeMinute
  ":".utf8
  timeSecond
  Optional.parser(of: timeSecfrac)
}

private let fullDate = Parse {
  dateFullyear
  "-".utf8
  dateMonth
  "-".utf8
  dateMday
}

private let offsetDateTime = Parse {
  fullDate
  timeDelim
  partialTime
  timeOffset
}
.map { date, time, timeZone -> DateComponents in
  let (year, month, day) = date
  let (hour, minute, second, nanosecond) = time
  return DateComponents(
    timeZone: timeZone,
    year: year, month: month, day: day,
    hour: hour, minute: minute, second: second, nanosecond: nanosecond
  )
}

private let localDateTime = Parse {
  fullDate
  timeDelim
  partialTime
}
.map { date, time -> DateComponents in
  let (year, month, day) = date
  let (hour, minute, second, nanosecond) = time
  return DateComponents(
    year: year, month: month, day: day,
    hour: hour, minute: minute, second: second, nanosecond: nanosecond
  )
}

private let localDate =
  fullDate
  .map { DateComponents(year: $0, month: $1, day: $2) }

private let localTime =
  partialTime
  .map { DateComponents(hour: $0, minute: $1, second: $2, nanosecond: $3) }

// MARK: - Suite

let dateSuite = BenchmarkSuite(name: "Date") { suite in
  let input = "1979-05-27T00:32:00Z"
  let expected = Date(timeIntervalSince1970: 296_613_120)
  var output: Date!

  let dateTimeParser = dateTime.compactMap(Calendar.current.date(from:))
  suite.benchmark(
    name: "Parser",
    run: { output = dateTimeParser.parse(input) },
    tearDown: { precondition(output == expected) }
  )

  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
  dateFormatter.locale = Locale(identifier: "en_US_POSIX")
  dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)!
  suite.benchmark(
    name: "DateFormatter",
    run: { output = dateFormatter.date(from: input) },
    tearDown: { precondition(output == expected) }
  )

  if #available(macOS 10.12, *) {
    let iso8601DateFormatter = ISO8601DateFormatter()
    iso8601DateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    suite.benchmark(
      name: "ISO8601DateFormatter",
      run: { output = iso8601DateFormatter.date(from: input) },
      tearDown: { precondition(output == expected) }
    )
  }
}