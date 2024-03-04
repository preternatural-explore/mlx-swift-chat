// Copyright © 2024 Apple Inc.

import Foundation

public enum ModelType: String, Codable {
    case mistral
    case llama
    case phi
    case gemma
    case stableLM = "stablelm_epoch"
    
    func createModel(
        configuration: URL
    ) throws -> LLMModel {
        switch self {
            case .mistral, .llama:
                let configuration = try JSONDecoder().decode(
                    LlamaConfiguration.self,
                    from: Data(contentsOf: configuration)
                )
                
                return LlamaModel(configuration)
            case .phi:
                let configuration = try JSONDecoder().decode(
                    PhiConfiguration.self,
                    from: Data(contentsOf: configuration)
                )
                
                return PhiModel(configuration)
            case .gemma:
                let configuration = try JSONDecoder().decode(
                    GemmaConfiguration.self,
                    from: Data(contentsOf: configuration)
                )
                
                return GemmaModel(configuration)
            case .stableLM:
                let configuration = try JSONDecoder().decode(
                    StableLMConfiguration.self,
                    from: Data(contentsOf: configuration)
                )
                
                return StableLMModel(config: configuration)
        }
    }
}

public struct BaseConfiguration: Codable {
    let modelType: ModelType
    
    public struct Quantization: Codable {
        public init(groupSize: Int, bits: Int) {
            self.groupSize = groupSize
            self.bits = bits
        }
        
        let groupSize: Int
        let bits: Int
        
        enum CodingKeys: String, CodingKey {
            case groupSize = "group_size"
            case bits = "bits"
        }
    }
    
    var quantization: Quantization?
    
    enum CodingKeys: String, CodingKey {
        case modelType = "model_type"
        case quantization
    }
}
