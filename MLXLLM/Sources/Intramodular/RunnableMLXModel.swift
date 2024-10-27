//
// Copyright (c) Vatsal Manot
//

import Generation
import MLX
import MLXRandom
import Tokenizers

class RunnableMLXModel: RunnableLLM {
    public enum ModelState {
        case uninitialized
        case loading
        case ready(Double?)
        case generating(Double)
        case failed(String)
    }
    
    public var modelState: ModelState = .uninitialized
    
    public private(set) var defaultGenerationConfig: GenerationConfig
    
    private var model: LLMModel?
    private var tokenizer: Tokenizer?
    private let modelStore: ModelStore
    private let modelID: ModelStore.Model.ID
    private let seed: UInt64

    @MainActor(unsafe)
    init(
        model: ModelStore.Model.ID,
        maxTokens: Int,
        temperature: Float,
        seed: UInt64,
        modelStore: ModelStore? = nil
    ) {
        self.modelStore = modelStore ?? ModelStore.shared
        self.modelID = model

        self.defaultGenerationConfig = .init(maxNewTokens: maxTokens, doSample: true)
        self.defaultGenerationConfig.temperature = .init(temperature)

        self.seed = seed
        
        MLXRandom.seed(seed)
    }
    
    func loadModel() async throws {
        self.modelState = .loading
        
        do {
            let (model, tokenizer) = try await modelStore.load(model: modelID)
        
            self.model = model
            self.tokenizer = tokenizer
            self.modelState = .ready(nil)
        } catch {
            self.modelState = .failed("Failed to load model: \(error.localizedDescription)")
            
            throw Error.modelLoadingFailed(error)
        }
    }
    
    func generate(
        config: GenerationConfig,
        prompt: String
    ) async throws -> String {
        #if DEBUG
        try await MainActor.run {
            try _generate(config: config, prompt: prompt)
        }
        #else
        try _generate(config: config, prompt: prompt)
        #endif
    }
    
    @_optimize(speed)
    private func _generate(
        config: GenerationConfig,
        prompt: String
    ) throws -> String {
        guard let model = model, let tokenizer = tokenizer else {
            self.modelState = .failed("Model is not loaded")
            
            throw Error.modelNotLoaded
        }
        
        self.modelState = .generating(0.0)
        
        let promptArray = MLXArray(tokenizer.encode(text: prompt))
        var tokens = [Int]()
        var progress: Double = 0
        
        for token in TokenIterator(
            prompt: promptArray,
            model: model,
            temperature: Float(config.temperature)
        ) {
            let tokenId = token.item(Int.self)
            
            if tokenId == tokenizer.unknownTokenId || tokens.count == config.maxNewTokens {
                break
            }
            
            tokens.append(tokenId)
            
            progress = Double(tokens.count) / Double(config.maxNewTokens)
            
            self.modelState = .generating(progress)
        }
        
        self.modelState = .ready(progress)
        
        return tokenizer.decode(tokens: tokens)
    }
    
    func generate(
        configuration: GenerationConfig,
        prompt: String,
        callback: ((String) -> Void)?
    ) async throws -> String {
        try await generate(config: configuration, prompt: prompt)
    }
}

// MARK: - Error Handling

extension RunnableMLXModel {
    enum Error: Swift.Error {
        case modelNotLoaded
        case modelLoadingFailed(Swift.Error)
        case generationFailed(String)
    }
}
