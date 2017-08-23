import Core

public final class Var: Tag {
    public init() {}

    public func render(parsed: ParsedTag, context: inout Context, renderer: Renderer) throws -> Future<Context?> {
        let promise = Promise(Context?.self)

        func updateContext(with c: Context) {
            context = c
        }

        if case .dictionary(var dict) = context {
            switch parsed.parameters.count {
            case 1:
                let body = try parsed.requireBody()
                let key = parsed.parameters[0].string ?? ""

                let serializer = Serializer(ast: body, renderer: renderer, context: context)

                // FIXME: any way to make this not sync?
                try serializer.serialize().then { rendered in
                    if let string = String(data: rendered, encoding: .utf8) {
                        dict[key] = .string(string)
                        updateContext(with: .dictionary(dict))
                        promise.complete(nil)
                    } else {
                        promise.fail("could not do string")
                    }
                }.catch { error in
                    promise.fail(error)
                }
            case 2:
                let key = parsed.parameters[0].string ?? ""
                dict[key] = parsed.parameters[1]
                updateContext(with: .dictionary(dict))
                promise.complete(nil)
            default:
                try parsed.requireParameterCount(2)
            }
        } else {
            promise.complete(nil)
        }

        return promise.future
    }
}
