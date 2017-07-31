import Bits

final class Serializer {
    let ast: [Syntax]
    var context: Data
    let renderer: Renderer

    init(ast: [Syntax], renderer: Renderer,  context: Data) {
        self.ast = ast
        self.context = context
        self.renderer = renderer
    }

    func serialize() throws -> Bytes {
        var serialized: Bytes = []

        for syntax in ast {
            do {
                switch syntax.kind {
                case .raw(let data):
                    serialized += data
                case .tag(let name, let parameters, let body, let chained):
                    let bytes: Bytes
                    if let data = try renderTag(name: name, parameters: parameters, body: body, chained: chained) {
                        guard let string = data.string else {
                            throw SerializerError.unexpectedSyntax(syntax)
                        }
                        bytes = string.makeBytes()
                    }else {
                        bytes = []
                    }
                    serialized += bytes
                default:
                    throw SerializerError.unexpectedSyntax(syntax)
                }
            } catch {
                throw RenderError(
                    source: syntax.source,
                    error: error
                )
            }
        }

        return serialized
    }

    private func renderTag(name: Syntax, parameters: [Syntax], body: [Syntax]?, chained: Syntax?) throws -> Data? {
        guard case .identifier(let id) = name.kind else {
            throw SerializerError.unexpectedSyntax(name)
        }

        guard let tag = renderer.tags[id] else {
            throw SerializerError.unknownTag(name: id)
        }

        var inputs: [Data?] = []

        for parameter in parameters {
            let input = try resolveSyntax(parameter)
            inputs.append(input)
        }

        if let data = try tag.render(
            parameters: inputs,
            context: &context,
            body: body,
            renderer: renderer
        ) {
            return data
        } else if let chained = chained {
            switch chained.kind {
            case .tag(let name, let params, let body, let chained):
                return try renderTag(name: name, parameters: params, body: body, chained: chained)
            default:
                throw SerializerError.unexpectedSyntax(chained)
            }
        } else {
            return nil
        }


    }

    private func resolveConstant(_ const: Constant) throws -> Data {
        switch const {
        case .double(let double):
            return .double(double)
        case .int(let int):
            return .int(int)
        case .string(let ast):
            let serializer = Serializer(ast: ast, renderer: renderer, context: context)
            let bytes = try serializer.serialize()
            return .string(bytes.makeString())
        }
    }

    private func resolveExpression(_ op: Operator, left: Syntax, right: Syntax) throws -> Data {
        let left = try resolveSyntax(left)
        let right = try resolveSyntax(right)

        guard let leftDouble = left?.double else {
            throw SerializerError.invalidNumber(left)
        }

        guard let rightDouble = right?.double else {
            throw SerializerError.invalidNumber(right)
        }

        switch op {
        case .add:
            return .double(leftDouble + rightDouble)
        case .subtract:
            return .double(leftDouble - rightDouble)
        case .greaterThan:
            return .bool(leftDouble > rightDouble)
        case .lessThan:
            return .bool(leftDouble < rightDouble)
        }
    }

    private func resolveSyntax(_ syntax: Syntax) throws -> Data? {
        switch syntax.kind {
        case .constant(let constant):
            return try resolveConstant(constant)
        case .expression(let op, let left, let right):
            return try resolveExpression(op, left: left, right: right)
        case .identifier(let id):
            guard let data = context.dictionary?[id] else {
                return nil
            }
            return data
        case .tag(let name, let parameters, let body, let chained):
            return try renderTag(name: name, parameters: parameters, body: body, chained: chained)
        default:
            throw SerializerError.unexpectedSyntax(syntax)
        }
    }
}
