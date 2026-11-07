import Foundation

/// Fixes the casing speech models get wrong for technical words, plus the
/// person's own vocabulary. Matching is whole-word and case-insensitive, and
/// filenames, domains and paths are left alone.
enum TechnicalTerms {
    private static let builtIn: [(spoken: String, written: String)] = [
        ("javascript", "JavaScript"), ("typescript", "TypeScript"), ("swiftui", "SwiftUI"),
        ("nextjs", "Next.js"), ("next.js", "Next.js"), ("postgresql", "PostgreSQL"),
        ("postgres", "Postgres"), ("mongodb", "MongoDB"), ("supabase", "Supabase"),
        ("graphql", "GraphQL"), ("github", "GitHub"), ("gitlab", "GitLab"), ("bitbucket", "Bitbucket"),
        ("macos", "macOS"), ("ios", "iOS"), ("ipados", "iPadOS"), ("watchos", "watchOS"),
        ("xcode", "Xcode"), ("appkit", "AppKit"), ("coregraphics", "CoreGraphics"),
        ("avfoundation", "AVFoundation"), ("openai", "OpenAI"), ("chatgpt", "ChatGPT"),
        ("pytorch", "PyTorch"), ("tensorflow", "TensorFlow"), ("onnx", "ONNX"),
        ("api", "API"), ("sdk", "SDK"), ("cli", "CLI"), ("ide", "IDE"), ("orm", "ORM"),
        ("cdn", "CDN"), ("dns", "DNS"), ("ssl", "SSL"), ("tls", "TLS"), ("ssh", "SSH"),
        ("html", "HTML"), ("css", "CSS"), ("xml", "XML"), ("sql", "SQL"), ("jwt", "JWT"),
        ("csv", "CSV"), ("pdf", "PDF"), ("svg", "SVG"), ("png", "PNG"), ("json", "JSON"),
        ("yaml", "YAML"), ("toml", "TOML"), ("uuid", "UUID"), ("http", "HTTP"), ("https", "HTTPS"),
        ("cors", "CORS"), ("crud", "CRUD"), ("rest", "REST"), ("grpc", "gRPC"),
        ("tcp", "TCP"), ("udp", "UDP"), ("vpn", "VPN"), ("cpu", "CPU"), ("gpu", "GPU"),
        ("npm", "npm"), ("npx", "npx"), ("aws", "AWS"), ("gcp", "GCP"), ("ec2", "EC2"),
        ("s3", "S3"), ("llm", "LLM"), ("gpt", "GPT"), ("rag", "RAG"), ("nlp", "NLP"), ("ai", "AI"),
    ]

    /// Ordinary English words that are only technical inside developer tools.
    private static let ambiguous: Set<String> = ["rest", "rag", "crud", "ai"]

    /// Letter-by-letter dictation, corrected only where code is being written.
    private static let spelledOut: [(spoken: String, written: String)] = [
        ("n p m", "npm"), ("n p x", "npx"), ("g i t h u b", "GitHub"),
        ("j s o n", "JSON"), ("a p i", "API"), ("c l i", "CLI"), ("s d k", "SDK"),
    ]

    static func apply(
        to text: String,
        destination: TextDestination,
        vocabulary: [VocabularyTerm],
        includeBuiltIn: Bool
    ) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        let personal = Set(vocabulary.map { $0.spoken.lowercased() })
        if includeBuiltIn {
            if destination != .general {
                for term in spelledOut where !personal.contains(term.spoken) {
                    result = replaceWholePhrase(term.spoken, with: term.written, in: result)
                }
            }
            for term in builtIn where !personal.contains(term.spoken) {
                guard destination != .general || !ambiguous.contains(term.spoken) else { continue }
                result = replaceWholePhrase(term.spoken, with: term.written, in: result)
            }
        }
        for term in vocabulary {
            result = replaceWholePhrase(term.spoken, with: term.written, in: result)
        }
        return result
    }

    private static let leadingBoundary = #"\p{L}\p{M}0-9_./\-"#
    private static let trailingBoundary = #"\p{L}\p{M}0-9_/-"#

    private static func replaceWholePhrase(_ phrase: String, with replacement: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = "(?i)(?<![\(leadingBoundary)])\(escaped)(?![\(trailingBoundary)])(?!\\.[\(trailingBoundary)])"
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let mutable = NSMutableString(string: text)
        for match in expression.matches(in: text, range: NSRange(location: 0, length: mutable.length)).reversed() {
            mutable.replaceCharacters(in: match.range, with: replacement)
        }
        return mutable as String
    }
}
