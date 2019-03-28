import Foundation
import SwiftSyntax

class Parser: SyntaxVisitor {
    private(set) var tokens: [TokenSyntax] = []
    private var index = 0
    private(set) var currentToken: TokenSyntax!

    // MARK: Practice 1

    override func visit(_ token: TokenSyntax) {
        print("Parsing \(token.tokenKind)")
        self.tokens.append(token)
    }

    @discardableResult
    func read() -> TokenSyntax {
        defer {
            self.index += 1
        }
        self.currentToken = tokens[self.index]
        return tokens[self.index]
    }

    func peek(_ n: Int = 0) -> TokenSyntax {
        return tokens[self.index + n]
    }

    // MARK: Practice 2

    private func extractNumberLiteral(from token: TokenSyntax) -> Double? {
        switch token.tokenKind {
        case .integerLiteral(let value):
            return Double(value)
        case .floatingLiteral(let value):
            return Double(value)
        default:
            fatalError("not integer value")
        }
    }

    func parseNumber() -> Node {
        guard let value = extractNumberLiteral(from: currentToken) else {
            fatalError("any number is expected")
        }
        read() // eat literal
        return NumberNode(value: value)
    }

    func parseIdentifierExpression() -> Node {
        let identifier: String
        
        switch currentToken.tokenKind {
        case .identifier(let value):
            identifier = value
            break
        default:
            fatalError("token: \(currentToken.tokenKind)")
        }
        
        read()
        
        guard currentToken.tokenKind == .leftParen else {
            return VariableNode(identifier: identifier)
        }
        
        return self.callExpression(callee: identifier)
    }
    
    private func callExpression(callee: String) -> CallExpressionNode {
        defer {
            read()
        }
        var arguments = [CallExpressionNode.Argument]()
        read()
        ///引数無し判定
        if currentToken.tokenKind != .rightParen {
            repeat {
                defer {
                    ///comma判定
                    if currentToken.tokenKind == .comma {
                        read()
                    }
                }
                ///引数のラベル
                let label: String
                switch currentToken.tokenKind {
                case .identifier(let id):
                    ///引数のラベルと、処理をAppend
                    label = id
                    break
                default:
                    fatalError("it isn't identifier... token: \(currentToken.tokenKind)")
                }
                read()
                guard currentToken.tokenKind == .colon else {
                    fatalError("it isn't colon... token: \(currentToken.tokenKind)")
                }
                read()
                
                arguments.append(CallExpressionNode.Argument(label: label, value: parseExpression()!))
            } while currentToken.tokenKind != .rightParen
        }
        
        return CallExpressionNode(callee: callee, arguments: arguments)
    }

    // MARK: Practice 3

    func extractBinaryOperator(from token: TokenSyntax) -> BinaryExpressionNode.Operator? {
        switch token.tokenKind {
        case .spacedBinaryOperator(let value):
            return BinaryExpressionNode.Operator(rawValue: value)
        case .unspacedBinaryOperator(let value):
            return BinaryExpressionNode.Operator(rawValue: value)
        default:
            return nil
        }
    }

    private func parseBinaryOperatorRHS(expressionPrecedence: Int, lhs: Node?) -> Node? {
        var currentLHS: Node? = lhs
        while true {
            let binaryOperator = extractBinaryOperator(from: currentToken!)
            let operatorPrecedence = binaryOperator?.precedence ?? -1
            
            // Compare between nextOperator's precedences and current one
            if operatorPrecedence < expressionPrecedence {
                return currentLHS
            }
            
            read() // eat binary operator
            var rhs = parsePrimary()
            if rhs == nil {
                return nil
            }
            
            // If binOperator binds less tightly with RHS than the operator after RHS, let
            // the pending operator take RHS as its LHS.
            let nextPrecedence = extractBinaryOperator(from: currentToken)?.precedence ?? -1
            if (operatorPrecedence < nextPrecedence) {
                // Search next RHS from currentRHS
                // next precedence will be `operatorPrecedence + 1`
                rhs = parseBinaryOperatorRHS(expressionPrecedence: operatorPrecedence + 1, lhs: rhs)
                if rhs == nil {
                    return nil
                }
            }
            
            guard let nonOptionalRHS = rhs else {
                fatalError("rhs must be nonnull")
            }
            
            currentLHS = BinaryExpressionNode(binaryOperator!,
                                              lhs: currentLHS!,
                                              rhs: nonOptionalRHS)
        }
    }

    // MARK: Practice 4

    func parseFunctionDefinitionArgument() -> FunctionNode.Argument {
      
        defer {
            read()
        }
        
        let variableName: String
        
        switch currentToken.tokenKind {
        case .identifier(let value):
            variableName = value
            read()
        default:
            fatalError("token: \(currentToken.tokenKind)")
        }
        
        switch currentToken.tokenKind {
        case .colon:
            read()
        default:
            fatalError("it isn't colon... token: \(currentToken.tokenKind)")
        }
        
        switch currentToken.tokenKind {
        case .identifier(let classType):
            print("class: \(classType)")
            return FunctionNode.Argument(label: variableName, variableName: variableName)
        default:
            fatalError("it isn't colon... token: \(currentToken.tokenKind)")
        }
    }

    func parseFunctionDefinition() -> Node {
        defer {
            read()
        }
        let name: String
        let classType: String
        var arguments = [FunctionNode.Argument]()
        let body: Node
        
        guard case .funcKeyword = currentToken.tokenKind else {
            fatalError("it isn't funcKeyword... token: \(currentToken.tokenKind)")
        }
        
        self.read()
        
        guard case TokenKind.identifier(let value) = currentToken.tokenKind else {
            fatalError("it isn't name... token: \(currentToken.tokenKind)")
        }
        
        name = value
        self.read()
        
        ///引数始めチェック
        guard case .leftParen = currentToken.tokenKind else {
            fatalError("it isn't leftParen... token: \(currentToken.tokenKind)")
        }
        
        self.read()
        ///引数無しチェック
        if currentToken.tokenKind != .rightParen {
            ///while文で引数を回してる
            repeat {
                defer {
                    //Colonを無視
                    if currentToken.tokenKind == .comma {
                        self.read()
                    }
                }
                arguments.append(parseFunctionDefinitionArgument())
            } while currentToken.tokenKind != .rightParen
        }
        
        self.read()
        
        guard case TokenKind.arrow = currentToken.tokenKind else {
            fatalError("it isn't arrow.. token: \(currentToken.tokenKind)")
        }
        
        self.read()
        
        guard case TokenKind.identifier(let c) = currentToken.tokenKind else {
            fatalError("it isn't class.. token: \(currentToken.tokenKind) ")
        }
        
        classType = c
        
        self.read()
        
        
        guard case TokenKind.leftBrace = currentToken.tokenKind else {
            fatalError("it isn't leftBrace.. token: \(currentToken.tokenKind)")
        }
        
        self.read()
        
        body = parseExpression()!
        
        guard let type = Type(rawValue: classType) else {
            fatalError("\(classType) is defind")
        }
        
        return FunctionNode(name: name, arguments: arguments, returnType: type, body: body)
    }

    // MARK: Practice 7

    func parseIfElse() -> Node {
        guard case TokenKind.ifKeyword = currentToken.tokenKind else {
            fatalError("it isn't ifKeyword")
        }
        
        self.read()
        
        if case TokenKind.leftParen = currentToken.tokenKind {
            self.read()
        }
        
        let condition: Node = parseExpression()!
        
        self.read()
        
        let then = parseExpression()!
        
        ///else直前の"}"ブロックチェック
        guard case TokenKind.rightBrace = currentToken.tokenKind else {
            fatalError("if isn't rightBrance...token: \(currentToken.tokenKind)")
        }
        self.read()
        ///elseキーワードチェック
        guard case TokenKind.elseKeyword = currentToken.tokenKind else {
            fatalError("it isn't elseKeyword...token: \(currentToken.tokenKind)")
        }
        
        self.read()
        
        ///else直後の"{"チェック
        guard case TokenKind.leftBrace = currentToken.tokenKind else {
            fatalError("it isn't leftBrance...token: \(currentToken.tokenKind)")
        }
        
        self.read()
        
        let elseblock = parseExpression()!
        return IfElseNode(condition: condition, then: then, else: elseblock)
    }

    // PROBABLY WORKS WELL, TRUST ME

    func parse() -> [Node] {
        var nodes: [Node] = []
        read()
        while true {
            switch currentToken.tokenKind {
            case .eof:
                return nodes
            case .funcKeyword:
                let node = parseFunctionDefinition()
                nodes.append(node)
            default:
                if let node = parseTopLevelExpression() {
                    nodes.append(node)
                    break
                } else {
                    read()
                }
            }
        }
        return nodes
    }

    private func parsePrimary() -> Node? {
        switch currentToken.tokenKind {
        case .identifier:
            return parseIdentifierExpression()
        case .integerLiteral, .floatingLiteral:
            return parseNumber()
        case .leftParen:
            return parseParen()
        case .funcKeyword:
            return parseFunctionDefinition()
        case .returnKeyword:
            return parseReturn()
        case .ifKeyword:
            return parseIfElse()
        case .eof:
            return nil
        default:
            fatalError("Unexpected token \(currentToken.tokenKind) \(currentToken.text)")
        }
        return nil
    }

    func parseExpression() -> Node? {
        guard let lhs = parsePrimary() else {
            return nil
        }
        return parseBinaryOperatorRHS(expressionPrecedence: 0, lhs: lhs)
    }

    private func parseReturn() -> Node {
        guard case .returnKeyword = currentToken.tokenKind else {
            fatalError("returnKeyword is expected but received \(currentToken.tokenKind)")
        }
        read() // eat return
        if let expression = parseExpression() {
            return ReturnNode(body: expression)
        } else {
            // return nothing
            return ReturnNode(body: nil)
        }
    }

    private func parseParen() -> Node? {
        read() // eat (
        guard let v = parseExpression() else {
            return nil
        }

        guard case .rightParen = currentToken.tokenKind else {
                fatalError("expected ')'")
        }
        read() // eat )

        return v
    }

    private func parseTopLevelExpression() -> Node? {
        if let expression = parseExpression() {
            // we treat top level expressions as anonymous functions
            let anonymousPrototype = FunctionNode(name: "main", arguments: [], returnType: .int, body: expression)
            return anonymousPrototype
        }
        return nil
    }
}

private extension BinaryExpressionNode.Operator {
    var precedence: Int {
        switch self {
        case .addition, .subtraction: return 20
        case .multication, .division: return 40
        case .lessThan: return 10
        case .greaterThan: return 10
        }
    }
}
