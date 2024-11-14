import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct DiscriminatedEnumMacro: ExtensionMacro {
    public static func expansion(of node: AttributeSyntax,
                                 attachedTo declaration: some DeclGroupSyntax,
                                 providingExtensionsOf type: some TypeSyntaxProtocol,
                                 conformingTo protocols: [TypeSyntax],
                                 in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration as? EnumDeclSyntax else {
            let enumError = Diagnostic(
                node: node,
                message: DiscriminatedEnumError.onlyApplicableToEnum
            )
            context.diagnose(enumError)
            return []
        }
        
        let arguments = node.arguments?.as(LabeledExprListSyntax.self)
//        
        let discriminatorKey = arguments?.first(where: { $0.label?.text == "discriminatorKey" }).map { StringLiteralExprSyntax($0.expression) } ?? StringLiteralExprSyntax(content: "tag")
        
        let members = enumDecl.memberBlock.members
        let caseDecls = members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
        let elements = caseDecls.flatMap { $0.elements }
        
        guard !elements.isEmpty else {
            let caseError = Diagnostic(
                node: declaration,
                message: DiscriminatedEnumError.atLeastOneCase
            )
            context.diagnose(caseError)
            return []
        }
        
        for element in elements {
            if let parameterClause = element.parameterClause,
               parameterClause.parameters.count > 1 || parameterClause.parameters.first!.firstName != nil {
                let associatedTypeError = Diagnostic(
                    node: parameterClause,
                    message: DiscriminatedEnumError.invalidAssociatedType
                )
                context.diagnose(associatedTypeError)
                return []
            }
        }
        
        let visibility = enumDecl.modifiers.filter { mod in
            switch mod.name.tokenKind {
            case .keyword(let keyword):
                [.public, .internal, .private, .open].contains(keyword)
            default:
                false
            }
        }
        
        let extensionDecl = try ExtensionDeclSyntax("extension \(type.trimmed): Decodable") {
            try EnumDeclSyntax("private enum CodingKeys: String, CodingKey") {
                try EnumCaseDeclSyntax("case tag = \(discriminatorKey)")
                
                for element in elements {
                    try EnumCaseDeclSyntax("case \(element.name) = \"\(raw: element.name.text.camelCaseToSnakeCase())\"")
                }
            }
            
            try EnumDeclSyntax("private enum Discriminator: String, Decodable") {
                for element in elements {
                    try EnumCaseDeclSyntax("case \(element.name) = \"\(raw: element.name.text.camelCaseToPascalCase())\"")
                }
            }
            
            try InitializerDeclSyntax("\(raw: visibility.map { $0.description + " " }.joined(separator: ""))init(from decoder: any Decoder) throws") {
                try VariableDeclSyntax("let container = try decoder.container(keyedBy: CodingKeys.self)")
                try VariableDeclSyntax("let tag = try container.decode(Discriminator.self, forKey: .tag)")
                
                try SwitchExprSyntax("switch tag") {
                    for element in elements {
                        if let parameterClause = element.parameterClause,
                           let firstParameter = parameterClause.parameters.first {
                                SwitchCaseSyntax(
                                    """
                                    case .\(element.name): 
                                        self = .\(element.name)(try container.decode(\(raw: firstParameter.type.description).self, forKey: .\(element.name)))
                                    """
                                )
                        } else {
                            SwitchCaseSyntax(
                                """
                                case .\(element.name):
                                    self = .\(element.name)
                                """
                            )
                        }
                    }
                }
            }
        }
        
        return [extensionDecl]
    }
}

enum DiscriminatedEnumError: String, DiagnosticMessage {
    case onlyApplicableToEnum
    case atLeastOneCase
    case invalidAssociatedType
    
    var severity: DiagnosticSeverity { return .error }
    
    var message: String {
        switch self {
        case .onlyApplicableToEnum: return "'@DiscriminatedEnum' can only be applied to an 'enum'"
        case .atLeastOneCase: return "The enumeration must define at least one case."
        case .invalidAssociatedType: return "A case with associated values may only have one parameter, which must be unnamed."
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "DiscriminatedEnumMacros", id: rawValue)
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
