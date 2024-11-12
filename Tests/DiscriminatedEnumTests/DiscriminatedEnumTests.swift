import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(DiscriminatedEnumMacros)
import DiscriminatedEnumMacros

let testMacros: [String: Macro.Type] = [
    "DiscriminatedEnum": DiscriminatedEnumMacro.self,
]
#endif

final class DiscriminatedEnumTests: XCTestCase {
    func testMacro() throws {
        #if canImport(DiscriminatedEnumMacros)
        assertMacroExpansion(
            """
            @DiscriminatedEnum
            enum Test {
                case hello, reallyCamel
                case world(Int)
            }
            """,
            expandedSource: """
            enum Test {
                case hello, reallyCamel
                case world(Int)
            }
            
            extension Test: Decodable {
                private enum CodingKeys: String, CodingKey {
                    case tag, hello = "hello", reallyCamel = "really_camel", world = "world"
                }

                private enum Discriminator: String, Decodable {
                    case hello = "Hello", reallyCamel = "ReallyCamel", world = "World"
                }

                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let tag = try container.decode(Discriminator.self, forKey: .tag)
                    switch tag {
                        case .hello:
                        self = .hello
                        case .reallyCamel:
                        self = .reallyCamel
                        case .world:
                        self = .world(try container.decode(Int.self, forKey: .world))
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
