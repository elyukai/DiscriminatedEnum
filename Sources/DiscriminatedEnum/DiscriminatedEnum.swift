// The Swift Programming Language
// https://docs.swift.org/swift-book

/// Provides `Decodable` conformance for an enumeration that is represented by a *tagged union*, or *discriminated union*, meaning that the serialized representation is an object with a property whose value defines the enumeration case, and optionally more properties to define associated values.
///
/// - parameter discriminatorKey: The name of the key that holds the discriminator.
@attached(extension, conformances: Decodable, names: named(init(from:)), named(CodingKeys), named(Discriminator))
public macro DiscriminatedEnum(discriminatorKey: String = "tag") = #externalMacro(module: "DiscriminatedEnumMacros", type: "DiscriminatedEnumMacro")
