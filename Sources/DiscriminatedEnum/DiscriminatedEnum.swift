// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(extension, conformances: Decodable, names: named(init(from:)), named(CodingKeys), named(Discriminator))
public macro DiscriminatedEnum() = #externalMacro(module: "DiscriminatedEnumMacros", type: "DiscriminatedEnumMacro")
