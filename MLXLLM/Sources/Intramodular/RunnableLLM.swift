//
// Copyright (c) Vatsal Manot
//

import Generation
import Models
import Swift

public protocol RunnableLLM {
    var defaultGenerationConfig: GenerationConfig { get }
    
    func generate(
        configuration: GenerationConfig,
        prompt: String,
        callback: ((String) -> Void)?
    ) async throws -> String
}

extension RunnableLLM {
    public var _modelDescription: String {
        String(describing: self)
    }
}

// MARK: - Implemented Conformances

extension Models.LanguageModel: RunnableLLM {
    public func generate(
        configuration: GenerationConfig,
        prompt: String,
        callback: ((String) -> Void)?
    ) async throws -> String {
        try await generate(config: configuration, prompt: prompt)
    }
}
