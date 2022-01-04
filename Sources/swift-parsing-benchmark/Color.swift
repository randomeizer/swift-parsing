import Benchmark
import Parsing

private struct Color: Equatable {
  let red, green, blue: UInt8
}

private typealias Input = Substring
private typealias Output = Color

private let hexPrimary = Prefix(2)
  .pipe {
    UInt8.parser(isSigned: false, radix: 16)
    End<Input>()
  }

private let hexColor = Parse(Color.init) {
  "#"
  hexPrimary
  hexPrimary
  hexPrimary
}

let colorSuite = BenchmarkSuite(name: "Color") { suite in
  let input = "#FF0000"
  let expected = Color(red: 0xFF, green: 0x00, blue: 0x00)
  var output: Color!

  suite.benchmark(
    name: "Parser",
    run: { output = hexColor.parse(input) },
    tearDown: { precondition(output == expected) }
  )
}
