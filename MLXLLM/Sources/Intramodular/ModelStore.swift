//
// Copyright (c) Vatsal Manot
//

import AsyncAlgorithms
import Foundation
import Hub
import MLX
import MLXNN
import MLXRandom
import SwiftUIX
import Tokenizers

public final class ModelStore: ObservableObject {
    @MainActor
    public static let shared = ModelStore()
        
    @Published public var suggestions: [Suggestion] = []
    @Published public var models: [Model] = []
    
    private let fileManager = FileManager.default
    
    private func hub() -> HubApi {
        @UserStorage("HuggingFaceToken") var token: String?
        
        let hub = HubApi(hfToken: token)
        
        return hub
    }
    
    private var downloadsURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        return documentsDirectory
            .appending(component: "huggingface")
            .appending(component: "models")
    }
    
    private let replacementTokenizers = [
        "CodeLlamaTokenizer": "LlamaTokenizer",
        "GemmaTokenizer": "PreTrainedTokenizer",
    ]
    
    @MainActor
    public init() {
        if !FileManager.default.fileExists(atPath: downloadsURL.path) {
            _ = try? FileManager.default.createDirectory(
                at: downloadsURL,
                withIntermediateDirectories: true
            )
        }
        
        self.suggestions = [
            Suggestion(name: "mlx-community/Nous-Hermes-2-Mistral-7B-DPO-4bit-MLX"),
            Suggestion(name: "mlx-community/Mistral-7B-v0.1-hf-4bit-mlx"),
        ]
        
        refreshFromDisk()
    }
    
    public func accept(_ suggestion: Suggestion) {
        Task {
            do {
                try await download(modelNamed: suggestion.name)
            } catch {
                print(error)
            }
        }
    }
        
    public func load(
        model modelID: Model.ID
    ) async throws -> (LLMModel, Tokenizer) {
        let model: any LLMModel = try await download(modelNamed: modelID)
        let tokenizer: any Tokenizer = try await loadTokenizer(for: modelID)

        return (model, tokenizer)
    }
    
    @discardableResult
    @MainActor
    public func download(
        modelNamed name: String
    ) async throws -> LLMModel {
        let model: Model
        
        if let existingModel = models.first(where: { $0.name == name }) {
            model = existingModel
        } else {
            assert(!models.contains(where: { $0.id == name }))
            
            model = Model(
                name: name,
                url: nil,
                state: .downloading(progress: 0)
            )
            
            self.models.append(model)
        }
        
        do {
            let result: any LLMModel = try await _downloadAndLoad(model: model.id)
            
            await MainActor.run {
                if let index = self.models.firstIndex(where: { $0.id == model.id }) {
                    self.models[index].state = .downloaded
                }
            }
            
            return result
        } catch {
            self[_model: model.id].state = .failed(String(describing: error))
            
            throw error
        }
    }
    
    private func _downloadAndLoad(
        model: Model.ID
    ) async throws -> LLMModel {
        let name: String = model // FIXME
        let repo = Hub.Repo(id: name)
        let modelFiles: [String] = [
            "config.json",
            "*.safetensors"
        ]
        let modelDirectory: URL = try await hub().snapshot(
            from: repo,
            matching: modelFiles,
            progressHandler: { progress in
                Task { @MainActor in
                    if let index = self.models.firstIndex(where: { $0.id == model }) {
                        self.models[index].state = .downloading(progress: progress.fractionCompleted)
                        
                        print("[\(name)] Download progress: \(progress.fractionCompleted * 100)")
                    } else {
                        assertionFailure()
                    }
                }
            }
        )
        
        await MainActor.run {
            self[_model: model].url = modelDirectory
        }
        
        let configurationURL: URL = modelDirectory.appending(component: "config.json")
        let baseConfig: BaseConfiguration = try JSONDecoder().decode(
            BaseConfiguration.self,
            from: Data(contentsOf: configurationURL)
        )
        let model: any LLMModel = try baseConfig.modelType.createModel(configuration: configurationURL)
        let weights: [String: MLXArray] = try loadWeights(from: modelDirectory)
        
        if let quantization = baseConfig.quantization {
            quantizeIfNeeded(model: model, weights: weights, quantization: quantization)
        }
        
        let parameters: NestedDictionary<String, MLXArray> = ModuleParameters.unflattened(consume weights)
        
        try model.update(parameters: parameters, verify: [.none])
            
        eval(model)
        
        return model
    }
}

@MainActor
extension ModelStore {
    public func containsModel(named name: String) -> Bool {
        models.contains(where: { $0.name == name })
    }
    
    public subscript(
        _model modelID: Model.ID
    ) -> Model {
        get {
            self.models.first(where: { $0.id == modelID })!
        } set {
            let index = self.models.firstIndex(where: { $0.id == modelID })!
            
            self.models[index] = newValue
        }
    }
    
    public subscript(
        _modelWithName name: String
    ) -> Model {
        get {
            self.models.first(where: { $0.name == name })!
        } set {
            let index = self.models.firstIndex(where: { $0.name == name })!
            
            self.models[index] = newValue
        }
    }

    public func delete(
        _ model: Model.ID
    ) {
        guard let model = models.first(where: { $0.id == model }) else {
            return
        }
        
        do {
            if let modelURL = model.url {
                try fileManager.removeItem(at: modelURL)
            }
            
            models.removeAll(where: { $0.id == model.id })
        } catch {
            assertionFailure(String(describing: error))
        }
    }
    
    private func refreshFromDisk() {
        let fileManager = FileManager.default
        
        do {
            let modelDirectories = try fileManager.contentsOfDirectory(
                at: downloadsURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ).flatMap {
                try fileManager.contentsOfDirectory(
                    at: $0,
                    includingPropertiesForKeys: nil,
                    options: .skipsHiddenFiles
                )
            }
            
            for directory in modelDirectories {
                let modelName: String = directory.deletingLastPathComponent().lastPathComponent + "/" + directory.lastPathComponent 
                let modelURL = directory
                let modelFiles = try fileManager.contentsOfDirectory(atPath: directory.path)
                let isDownloaded = modelFiles.contains(where: { $0.hasSuffix(".safetensors") })
                
                let model = Model(
                    name: modelName,
                    url: modelURL,
                    state: isDownloaded ? .downloaded : .notDownloaded
                )
                
                if self.containsModel(named: model.name) {
                    self[_modelWithName: model.name] = model
                } else {
                    self.models.append(model)
                }
            }
        } catch {
            print("Error loading models from disk: \(error)")
        }
    }
}

extension ModelStore {
    public func loadWeights(
        from directory: URL
    ) throws -> [String: MLXArray] {
        var weights = [String: MLXArray]()
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)!
        
        for case let url as URL in enumerator {
            if url.pathExtension == "safetensors" {
                let weightArrays = try loadArrays(url: url)
                for (key, value) in weightArrays {
                    weights[key] = value
                }
            }
        }
        
        return weights
    }
    
    public func loadTokenizer(
        for model: Model.ID
    ) async throws -> Tokenizers.Tokenizer {
        var model: String = await self[_model: model].name
        
        if model == "mlx-community/stablelm-2-zephyr-1_6b-4bit" {
            model = "stabilityai/stablelm-2-zephyr-1_6b"
        }
        do {
            let config = LanguageModelConfigurationFromHub(modelName: model)
            
            guard var tokenizerConfig = try await config.tokenizerConfig else {
                throw Error(message: "missing config")
            }
            
            var tokenizerData = try await config.tokenizerData
            
            if let tokenizerClass = tokenizerConfig.tokenizerClass?.stringValue,
               let replacement = replacementTokenizers[tokenizerClass] {
                var dictionary = tokenizerConfig.dictionary
                dictionary["tokenizer_class"] = replacement
                tokenizerConfig = Config(dictionary)
            }
            
            if let tokenizerClass = tokenizerConfig.tokenizerClass?.stringValue {
                switch tokenizerClass {
                    case "T5Tokenizer":
                        break
                    default:
                        tokenizerData = discardUnhandledMerges(tokenizerData: tokenizerData)
                }
            }
            
            return try PreTrainedTokenizer(
                tokenizerConfig: tokenizerConfig,
                tokenizerData: tokenizerData
            )
        } catch {
            return try await AutoTokenizer.from(pretrained: model)
        }
    }
    
    private func discardUnhandledMerges(
        tokenizerData: Config
    ) -> Config {
        if let model = tokenizerData.model {
            if let merges = model.dictionary["merges"] as? [String] {
                let newMerges =
                merges
                    .filter {
                        $0.split(separator: " ").count == 2
                    }
                if newMerges.count != merges.count {
                    var newModel = model.dictionary
                    newModel["merges"] = newMerges
                    var newTokenizerData = tokenizerData.dictionary
                    newTokenizerData["model"] = newModel
                    return Config(newTokenizerData)
                }
            }
        }
        return tokenizerData
    }
    
    private func quantizeIfNeeded(
        model: LLMModel, weights: [String: MLXArray], quantization: BaseConfiguration.Quantization
    ) {
        func linearPredicate(layer: Module) -> Bool {
            if let layer = layer as? Linear {
                return layer.weight.dim(0) != 8
            }
            return false
        }
        var predicate = linearPredicate(layer:)
        
        if weights["lm_head.scales"] == nil {
            let vocabularySize = model.vocabularySize
            func vocabularySizePredicate(layer: Module) -> Bool {
                if let layer = layer as? Linear {
                    return layer.weight.dim(0) != 8 && layer.weight.dim(0) != vocabularySize
                }
                return false
            }
            predicate = vocabularySizePredicate(layer:)
        }
        
        QuantizedLinear.quantize(
            model: model,
            groupSize: quantization.groupSize,
            bits: quantization.bits,
            predicate: predicate
        )
    }
}

extension ModelStore {
    public struct Model: Hashable, Identifiable, Sendable {
        public typealias ID = String
        
        public var name: String
        public var url: URL?
        public var state: DownloadState
        
        public var id: ID {
            name
        }
        
        public var displayName: String {
            url?.lastPathComponent ?? name
        }
        
        public enum DownloadState: Hashable, Sendable {
            case notDownloaded
            case downloading(progress: Double)
            case downloaded
            case failed(String)
        }
    }
    
    public struct Suggestion: Hashable, Identifiable, Sendable {
        public let name: String
        
        public var id: AnyHashable {
            name
        }
        
        public init(name: String) {
            self.name = name
        }
        
        public init(url: URL) {
            let name = url.path().deletingPrefix("huggingface.co").deletingPrefix("/")
            
            self.init(name: name)
        }
    }
}

extension ModelStore {
    struct Error: Swift.Error {
        let message: String
    }
}
