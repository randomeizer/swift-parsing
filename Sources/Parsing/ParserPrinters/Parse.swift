/// A parser that attempts to run a number of parsers to accumulate their outputs.
///
/// A general entry point into ``ParserBuilder`` syntax, which can be used to build complex parsers
/// from simpler ones.
///
/// ```swift
/// let point = Parse {
///   "("
///   Int.parser()
///   ","
///   Int.parser()
///   ")"
/// }
///
/// try point.parse("(2,-4)")  // (2, -4)
///
/// try point.parse("(42,blob)")
/// // error: unexpected input
/// //  --> input:1:5
/// // 1 | (42,blob)
/// //   |     ^ expected integer
/// ```
public struct Parse<Parsers: Parser>: Parser {
  public let parsers: Parsers

  @inlinable
  public init(@ParserBuilder _ build: () -> Parsers) {
    self.parsers = build()
  }

  @inlinable
  public init<Upstream, NewOutput>(
    _ transform: @escaping (Upstream.Output) -> NewOutput,
    @ParserBuilder with build: () -> Upstream
  ) where Parsers == Parsing.Parsers.Map<Upstream, NewOutput> {
    self.parsers = build().map(transform)
  }

  @inlinable
  public init<Upstream, NewOutput>(
    _ output: NewOutput,
    @ParserBuilder with build: () -> Upstream
  ) where Parsers == Parsing.Parsers.MapConstant<Upstream, NewOutput> {
    self.parsers = build().map { output }
  }

  @inlinable
  public init<Upstream, Downstream>(
    _ conversion: Downstream,
    @ParserBuilder with build: () -> Upstream
  ) where Parsers == Parsing.Parsers.MapConversion<Upstream, Downstream> {
    self.parsers = build().map(conversion)
  }

  @inlinable
  public func parse(_ input: inout Parsers.Input) rethrows -> Parsers.Output {
    try self.parsers.parse(&input)
  }
}

extension Parse: Printer where Parsers: Printer {
  @inlinable
  public func print(_ output: Parsers.Output, to input: inout Parsers.Input) rethrows {
    try self.parsers.print(output, to: &input)
  }
}

public typealias ParsePrint<P> = Parse<P> where P: ParserPrinter
