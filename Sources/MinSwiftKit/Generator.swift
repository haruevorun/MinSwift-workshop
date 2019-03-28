import Foundation
import LLVM

@discardableResult
func generateIRValue(from node: Node, with context: BuildContext) -> IRValue {
    switch node {
    case let numberNode as NumberNode:
        return Generator<NumberNode>(node: numberNode).generate(with: context)
    case let binaryExpressionNode as BinaryExpressionNode:
        return Generator<BinaryExpressionNode>(node: binaryExpressionNode).generate(with: context)
    case let variableNode as VariableNode:
        return Generator<VariableNode>(node: variableNode).generate(with: context)
    case let functionNode as FunctionNode:
        return Generator<FunctionNode>(node: functionNode).generate(with: context)
    case let callExpressionNode as CallExpressionNode:
        return Generator<CallExpressionNode>(node: callExpressionNode).generate(with: context)
    case let ifElseNode as IfElseNode:
        return Generator<IfElseNode>(node: ifElseNode).generate(with: context)
    case let returnNode as ReturnNode:
        return Generator<ReturnNode>(node: returnNode).generate(with: context)
    default:
        fatalError("Unknown node type \(type(of: node))")
    }
}

private protocol GeneratorProtocol {
    associatedtype NodeType: Node
    var node: NodeType { get }
    func generate(with: BuildContext) -> IRValue
    init(node: NodeType)
}

private struct Generator<NodeType: Node>: GeneratorProtocol {
    func generate(with context: BuildContext) -> IRValue {
        fatalError("Not implemented")
    }

    let node: NodeType
    init(node: NodeType) {
        self.node = node
    }
}

// MARK: Practice 6

extension Generator where NodeType == NumberNode {
    func generate(with context: BuildContext) -> IRValue {
        return FloatType.double.constant(node.value)
    }
}

extension Generator where NodeType == VariableNode {
    func generate(with context: BuildContext) -> IRValue {
        guard let variable = context.namedValues[node.identifier] else {
            fatalError("Undefined variable named a")
        }
        return variable
    }
}

extension Generator where NodeType == BinaryExpressionNode {
    func generate(with context: BuildContext) -> IRValue {
        let lhsVal: IRValue = generateIRValue(from: node.lhs, with: context)
        let rhsVal: IRValue = generateIRValue(from: node.rhs, with: context)
        
        switch node.operator {
        case .addition:
            return context.builder.buildAdd(lhsVal, rhsVal, name: "addtmp")
        case .subtraction:
            return context.builder.buildSub(lhsVal, rhsVal, name: "subtmp")
        case .multication:
            return context.builder.buildMul(lhsVal, rhsVal, name: "multmp")
        case .division:
            return context.builder.buildDiv(lhsVal, rhsVal, name: "divtmp")
        case .lessThan:
            let bool = context.builder.buildFCmp(lhsVal, rhsVal, .orderedLessThan, name: "cmptmp")
            return context.builder.buildIntToFP(bool, type: FloatType.double, signed: true)
        case .greaterThan:
            let bool = context.builder.buildFCmp(lhsVal, rhsVal, .orderedGreaterThan, name: "cmptmp")
            return context.builder.buildIntToFP(bool, type: FloatType.double, signed: true)
        }
    }
}

extension Generator where NodeType == FunctionNode {
    func generate(with context: BuildContext) -> IRValue {
        ///引数
        let argmentTypes = [IRType](repeating: FloatType.double, count: node.arguments.count)
        let returnType: IRType
        ///返り値
        switch node.returnType {
        case .double:
            returnType = FloatType.double
        default:
            fatalError()
        }
        
        let functionType = FunctionType(argTypes: argmentTypes, returnType: returnType)
        let function: Function = context.builder.addFunction(node.name, type: functionType)
        let entryBasicBlock = function.appendBasicBlock(named: "entry")
        context.builder.positionAtEnd(of: entryBasicBlock)
        
        context.namedValues.removeAll()
        //パラメーター設定
        for (index, arg) in node.arguments.enumerated() {
            context.namedValues[arg.variableName] = function.parameters[index]
        }
        
        let functionBody = generateIRValue(from: node.body, with: context)
        context.builder.buildRet(functionBody)
        return functionBody
    }
}

extension Generator where NodeType == CallExpressionNode {
    func generate(with context: BuildContext) -> IRValue {
        let function = context.module.function(named: node.callee)!
        var arguments = [IRValue]()
        for arg in node.arguments {
            arguments.append(generateIRValue(from: arg.value, with: context))
        }
        return context.builder.buildCall(function, args: arguments, name: "calltmp")
    }
}

extension Generator where NodeType == IfElseNode {
    func generate(with context: BuildContext) -> IRValue {
        let condition: IRValue = generateIRValue(from: node.condition, with: context)
        let boolean = context.builder.buildFCmp(condition, <#T##rhs: IRValue##IRValue#>, <#T##predicate: RealPredicate##RealPredicate#>, name: <#T##String#>)
    }
}

extension Generator where NodeType == ReturnNode {
    func generate(with context: BuildContext) -> IRValue {
        if let body = node.body {
            let returnValue = MinSwiftKit.generateIRValue(from: body, with: context)
            return returnValue
        } else {
            return VoidType().null()
        }
    }
}
