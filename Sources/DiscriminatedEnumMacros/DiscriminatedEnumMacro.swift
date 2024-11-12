import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DiscriminatedEnumMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax,
                                 attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard let enumDeclaration = declaration as? EnumDeclSyntax else {
            fatalError("The macro can only be attached to an enum declaration.")
        }
        
        let cases = enumDeclaration.memberBlock.members.compactMap { member in
            EnumCaseDeclSyntax(member.decl)
        }
        
        guard !cases.isEmpty else {
            fatalError("The enum declaration must contain at least one case.")
        }
        
        let caseElements: [EnumCaseElementSyntax] = cases.flatMap { enumCaseDeclaration in
            enumCaseDeclaration.elements
        }
        
        let caseNames = caseElements.map { enumCaseElement in
            enumCaseElement.name.text
        }
        
        let declSyntax: DeclSyntax =
            """
            extension \(type.trimmed): Decodable {
                private enum CodingKeys: String, CodingKey {
                    case tag, \(raw: caseNames.map { "\($0) = \"\($0.camelCaseToSnakeCase())\"" } .joined(separator: ", "))
                }
            
                private enum Discriminator: String, Decodable {
                    case \(raw: caseNames.map { "\($0) = \"\($0.camelCaseToPascalCase())\"" } .joined(separator: ", "))
                }
                
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    let tag = try container.decode(Discriminator.self, forKey: .tag)
                    switch tag {
                        \(raw: caseElements.map {
                            if let parameterClause = $0.parameterClause  {
                                guard parameterClause.parameters.count == 1 && parameterClause.parameters.first!.firstName == nil else {
                                    fatalError("A case with associated values may only have one unnamed parameter.")
                                }
                                return "case .\($0.name.text): self = .\($0.name.text)(try container.decode(\(parameterClause.parameters.first!.type.description).self, forKey: .\($0.name.text)))"
                            } else {
                                return "case .\($0.name.text): self = .\($0.name.text)"
                            }
                        }.joined(separator: "\n            "))
                    }
                }
            }
            """
        
        return [
            ExtensionDeclSyntax(declSyntax)!
        ]
    }
}

extension String {
    func camelCaseToSnakeCase() -> String {
        guard !self.isEmpty else { return self }
        
        let withSimpleTransformed = self.replacing(/([A-Z][a-z])/) { match in
            "_\(self[match.range].lowercased())"
        }
        
        let withAllCapsTransformed = withSimpleTransformed.replacing(/([A-Z]+)/) { match in
            "_\(self[match.range].lowercased())"
        }
        
        return withAllCapsTransformed
    }
    
    func camelCaseToPascalCase() -> String {
        guard !self.isEmpty else { return self }
        
        return self.first!.uppercased() + self.dropFirst()
    }
}

@main
struct DiscriminatedEnumPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DiscriminatedEnumMacro.self,
    ]
}
