//
// Copyright (c) Vatsal Manot
//

import Generation
import Models
import SwiftUI

@MainActor
public class LLMRunner: ObservableObject {
    public enum Framework {
        case huggingFace
        case mlx
    }
    
    private let modelStore = ModelStore.shared
    
    @Published public var framework: Framework = .mlx
    @Published public var configuration: GenerationConfig? = GenerationConfig(maxNewTokens: 100)
    @Published public var prompt: String = "Why did the chicken cross the road? "
    @Published public var model: ModelStore.Model.ID? = nil {
        didSet {
            if model != oldValue {
                modelDidChange()
            }
        }
    }
    
    @Published public private(set) var status: LLMRunnerStatus = .noModelSelected
    @Published public private(set) var llm: RunnableLLM? = nil
    @Published public private(set) var completionText: AttributedString?
    
    @MainActor(unsafe)
    public init() {

    }
    
    @MainActor
    private func modelDidChange() {
        guard status != .loadingModel else {
            return
        }
        
        status = .loadingModel
        
        Task.detached {
            do {
                if let model: ModelStore.Model.ID = await self.model {
                    try await self.load(model)
                }
            } catch {
                await MainActor.run {
                    self.status = .noModelSelected
                }
                
                print(error)
            }
        }
    }
    
    public func load(
        _ model: ModelStore.Model.ID
    ) async throws {
        switch framework {
            case .huggingFace:
                let model: ModelStore.Model = modelStore[_model: model]
                let llm = try await HuggingFaceModelLoader.load(url: model.url!)
                
                await MainActor.run {
                    self.configuration = llm.defaultGenerationConfig
                    self.llm = llm
                    self.status = .ready(nil)
                }
            case .mlx:
                let model = RunnableMLXModel(
                    model: model,
                    maxTokens: 100,
                    temperature: 1.0,
                    seed: 0
                )
                
                try await model.loadModel()
                
                await MainActor.run {
                    self.llm = model
                    self.configuration = model.defaultGenerationConfig
                    self.status = .ready(nil)
                }
        }
    }
        
    @MainActor
    public func run() {
        guard let llm else {
            return
        }
        
        let configuration: GenerationConfig = self.configuration ?? llm.defaultGenerationConfig
        
        if self.configuration == nil {
            self.configuration = configuration
        }
        
        Task.init {
            status = .generating(0)
            
            var tokensReceived = 0
            let begin = Date()
            
            do {
                let output = try await llm.generate(
                    configuration: configuration,
                    prompt: prompt
                ) { inProgressGeneration in
                    tokensReceived += 1
                    
                    self.showOutput(
                        currentGeneration: inProgressGeneration,
                        progress: Double(tokensReceived ) / Double(configuration.maxNewTokens)
                    )
                }
                
                let completionTime = Date().timeIntervalSince(begin)
                let tokensPerSecond = Double(tokensReceived) / completionTime
                
                showOutput(
                    currentGeneration: output,
                    progress: 1,
                    completedTokensPerSecond: tokensPerSecond
                )
                
                print("Took \(completionTime)")
            } catch {
                print("Error \(error)")
                Task { @MainActor in
                    status = .failed("\(error)")
                }
            }
        }
    }
    
    private func showOutput(
        currentGeneration: String,
        progress: Double,
        completedTokensPerSecond: Double? = nil
    ) {
        Task { @MainActor in
            var response = currentGeneration.deletingPrefix("<s> ")
            
            guard response.count > prompt.count else {
                return
            }
            
            response = response.replacingOccurrences(of: "\\n", with: "\n")
            
            var styledPrompt = AttributedString(prompt)
            styledPrompt.foregroundColor = .primary
            
            var styledOutput = AttributedString(response)
            styledOutput.foregroundColor = .primary
            styledOutput.backgroundColor = Color.yellow.opacity(0.2)
            
            completionText = styledPrompt + styledOutput
            
            if let tps = completedTokensPerSecond {
                status = .ready(tps)
            } else {
                status = .generating(progress)
            }
        }
    }
}

public enum LLMRunnerStatus: Hashable {
    case noModelSelected
    case loadingModel
    case ready(Double?)
    case generating(Double)
    case failed(String)
    
    public enum _ComparsionType {
        case ready
        case failed
        
        public static func == (lhs: Self, rhs: LLMRunnerStatus) -> Bool {
            switch (lhs, rhs) {
                case (.ready, .ready):
                    return true
                case (.failed, .failed):
                    return true
                default:
                    return false
            }
        }
        
        public static func == (lhs: LLMRunnerStatus, rhs: Self) -> Bool {
            rhs == lhs
        }
    }
}
