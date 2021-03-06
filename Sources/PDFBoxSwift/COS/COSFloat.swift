//
//  COSFloat.swift
//  PDFBoxSwiftCOS
//
//  Created by Sergej Jaskiewicz on 09/01/2019.
//

/// This class represents a floating point number in a PDF document.
public final class COSFloat: COSNumber, Decodable {

  private let stringValue: String

  /// Constructor.
  ///
  /// - Parameter value: The value that this object wraps.
  public init<T: FloatingPoint & LosslessStringConvertible>(value: T) {
    self.stringValue = String(value)
  }

  /// Constructor.
  ///
  /// - Parameter string: A string representation of a floating point number.
  /// - Throws: `COSNumber.ParseError` if `string` is not a float.
  public init<S: StringProtocol>(string: S) throws {

    if Double(string) == nil {

      if string.hasPrefix("--") {

        // https://issues.apache.org/jira/browse/PDFBOX-4289
        // has --16.33
        stringValue = String(string.dropFirst())
      } else if containsMinusInWrongPlace(string) {

        // https://issues.apache.org/jira/browse/PDFBOX-2990
        // has 0.00000-33917698

        // https://issues.apache.org/jira/browse/PDFBOX-3369
        // has 0.00-35095424

        // https://issues.apache.org/jira/browse/PDFBOX-3500
        // has 0.-262
        stringValue = "-" + removeMinus(string)
      } else {
        throw ParseError(
          "Error: expected floating point number, actual value: '\(string)'"
        )
      }
    } else {
      stringValue = String(string)
    }
  }

  public convenience init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    try self.init(value: container.decode(Double.self))
  }

  public override func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(doubleValue)
  }

  public override var floatValue: Float {
    return Float(stringValue) ?? 0
  }

  public override var doubleValue: Double {
    return Double(stringValue) ?? 0
  }

  public override var intValue: Int64 {
    return Int64(max(min(doubleValue, Double(Int64.max)), Double(Int64.min)))
  }

  public override func isEqual(_ other: COSBase) -> Bool {
    guard let other = other as? COSFloat else { return false }
    return other.floatValue.bitPattern == self.floatValue.bitPattern
  }

  public override func hash(into hasher: inout Hasher) {
    hasher.combine(stringValue)
  }

  @discardableResult
  public override func accept(visitor: COSVisitorProtocol) throws -> Any? {
    return try visitor.visit(self)
  }

  /// This will write this object out to a PDF stream.
  ///
  /// - Parameter output: The stream to write to.
  /// - Throws: Any error the stream throws during writing.
  public func writePDF(_ output: OutputStream) throws {
    try output.write(utf8: stringValue)
  }

  public override var debugDescription: String {
    return "COSFloat{\(stringValue)}"
  }
}

/// Whether `value` matches the `^0\.0*\-\d+` regex.
///
/// We don't want to depend on Foundation, so we can't use regexes.
private func containsMinusInWrongPlace<S: StringProtocol>(_ value: S) -> Bool {

  guard value.hasPrefix("0.") else { return false }

  var iterator = value.makeIterator()

  var lastChar = iterator.next()
  lastChar = iterator.next()

  while let head = iterator.next() {
    lastChar = head
    if head != "0" {
      break
    }
  }

  guard lastChar == "-" else { return false }

  guard iterator.next()?.isDigit ?? false else {
    return false
  }

  while let head = iterator.next() {
    if !head.isDigit {
      return false
    }
  }

  return true
}

private func removeMinus<S: StringProtocol>(_ value: S) -> String {
  return String(value.lazy.compactMap { $0 == "-" ? nil : $0 })
}

extension Character {
  fileprivate var isDigit: Bool {
    return Int(String(self)) != nil
  }
}
