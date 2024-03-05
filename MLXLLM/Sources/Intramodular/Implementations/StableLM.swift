//
// Copyright (c) Vatsal Manot
//

import Foundation
import MLX
import MLXNN

private class LayerNorm: MLXNN.LayerNorm {
    override func callAsFunction(_ x: MLXArray) -> MLXArray {
        super.callAsFunction(x.asType(Float.self)).asType(x.dtype)
    }
}

private class Attention: Module {
    
    let args: StableLMConfiguration
    let heads: Int
    let headDim: Int
    let repeats: Int
    
    @ModuleInfo(key: "q_proj") var wq: Linear
    @ModuleInfo(key: "k_proj") var wk: Linear
    @ModuleInfo(key: "v_proj") var wv: Linear
    @ModuleInfo(key: "dense") var dense: Linear
    
    let rope: RoPE
    
    public init(_ args: StableLMConfiguration) {
        self.args = args
        
        let hiddenSize = args.hiddenSize
        self.heads = args.attentionHeads
        self.headDim = args.hiddenSize / heads
        let kvHeads = args.kvHeads
        self.repeats = heads / kvHeads
        
        if headDim * heads != hiddenSize {
            fatalError("hidden_size must be divisible by num_heads")
        }
        
        self._wq.wrappedValue = Linear(hiddenSize, heads * headDim, bias: args.useQKVBias)
        self._wk.wrappedValue = Linear(hiddenSize, kvHeads * headDim, bias: args.useQKVBias)
        self._wv.wrappedValue = Linear(hiddenSize, kvHeads * headDim, bias: args.useQKVBias)
        self._dense.wrappedValue = Linear(heads * headDim, hiddenSize, bias: true)
        
        self.rope = RoPE(
            dimensions: Int(args.partialRotaryFactor * Float(headDim)), 
            traditional: false,
            base: args.ropeTheta
        )
    }
    
    public func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray? = nil,
        cache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray)) {
        var queries = wq(x)
        var keys = wk(x)
        var values = wv(x)
        
        let (B, L, _) = (x.dim(0), x.dim(1), x.dim(2))

        // prepare the queries, keys and values for the attention computation
        queries = queries.reshaped(B, L, heads, headDim).transposed(0, 2, 1, 3)
        keys = keys.reshaped(B, L, args.kvHeads, headDim).transposed(0, 2, 1, 3)
        values = values.reshaped(B, L, args.kvHeads, headDim).transposed(0, 2, 1, 3)
        
        if repeats > 1 {
            keys = MLXArray.repeat(keys, count: repeats, axis: 1)
            values = MLXArray.repeat(values, count: repeats, axis: 1)
        }
        
        // Add RoPE to the queries and keys and combine them with the cache
        if let (keyCache, valueCache) = cache {
            queries = rope(queries, offset: keyCache.dim(2))
            keys = rope(keys, offset: keyCache.dim(2))
            keys = concatenated([keyCache, keys], axis: 2)
            values = concatenated([valueCache, values], axis: 2)
        } else {
            queries = rope(queries)
            keys = rope(keys)
        }
        
        queries = queries.asType(Float.self)
        keys = keys.asType(Float.self)
        
        // Finally perform the attention computation
        let scale = sqrt(1 / Float(queries.dim(-1)))
        var scores = (queries * scale).matmul(keys.transposed(0, 1, 3, 2))
        
        if let mask {
            scores = scores + mask
        }
        
        scores = softMax(scores, axis: -1).asType(values.dtype)
        let valuesHat = (scores.matmul(values)).transposed(0, 2, 1, 3).reshaped(B, L, -1)
    
        return (dense(valuesHat), (keys, values))
    }
}

private class MLP: Module {
    @ModuleInfo(key: "fc1") var gateProj: Linear
    @ModuleInfo(key: "fc2") var downProj: Linear
    @ModuleInfo(key: "fc3") var upProj: Linear

    init(dim: Int, hiddenDim: Int) {
        super.init()
        
        gateProj = Linear(dim, hiddenDim, bias: false)
        downProj = Linear(hiddenDim, dim, bias: false)
        upProj = Linear(dim, hiddenDim, bias: false)
    }
    
    public func callAsFunction(_ x: MLXArray) -> MLXArray {
        return self.downProj(silu(self.gateProj(x)) * self.upProj(x))
    }
}

private class DecoderLayer: Module {
    @ModuleInfo(key: "self_attn") var selfAttention: Attention
    @ModuleInfo(key: "input_layernorm") var inputLayerNorm: LayerNorm
    @ModuleInfo(key: "post_attention_layernorm") var postAttentionLayerNorm: LayerNorm

    var mlp: MLP

    init(_ config: StableLMConfiguration) {
        self._selfAttention.wrappedValue = Attention(config)
        self.mlp = MLP(
            dim: config.hiddenSize,
            hiddenDim: config.intermediateSize
        )
        self._inputLayerNorm.wrappedValue = LayerNorm(
            dimensions: config.hiddenSize,
            eps: config.layerNormEps
        )
        self._postAttentionLayerNorm.wrappedValue = LayerNorm(
            dimensions: config.hiddenSize,
            eps: config.layerNormEps
        )
    }
    
    public func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray? = nil,
        cache: (MLXArray, MLXArray)? = nil
    ) -> (MLXArray, (MLXArray, MLXArray)) {
        let h = inputLayerNorm(x)
        let (attentionH, cache) = selfAttention(h, mask: mask, cache: cache)
        let ffH = mlp(h)
        return (attentionH + ffH + x, cache)
    }
}

private class StableLMModelInner: Module {
    @ModuleInfo(key: "embed_tokens") var embedTokens: Embedding
    var layers: [DecoderLayer]
    @ModuleInfo(key: "final_layernorm") var finalLayerNorm: LayerNorm
    
    init(_ config: StableLMConfiguration) {
        self._embedTokens.wrappedValue = Embedding(
            embeddingCount: config.vocabSize,
            dimensions: config.hiddenSize
        )
        self.layers = (0 ..< config.numHiddenLayers)
            .map { _ in
                DecoderLayer(config)
            }
        self._finalLayerNorm.wrappedValue = LayerNorm(
            dimensions: config.hiddenSize,
            eps: config.layerNormEps
        )
    }
    
    public func callAsFunction(
        _ x: MLXArray,
        mask: MLXArray? = nil,
        cache: [(MLXArray, MLXArray)]? = nil
    ) -> (MLXArray, [(MLXArray, MLXArray)]) {
        var x = embedTokens(x)
        
        var newCache = [(MLXArray, MLXArray)]()
        
        for (i, layer) in layers.enumerated() {
            var cacheUpdate: (MLXArray, MLXArray)
            (x, cacheUpdate) = layer(x, mask: mask, cache: cache?[i])
            newCache.append(cacheUpdate)
        }
        
        return (finalLayerNorm(x), newCache)
    }
}

public class StableLMModel: Module, LLMModel {
    public var vocabularySize: Int
    
    @ModuleInfo fileprivate var model: StableLMModelInner
    @ModuleInfo(key: "lm_head") var lmHead: Linear
    
    init(config: StableLMConfiguration) {
        self.vocabularySize = config.vocabSize
        self.model = StableLMModelInner(config)
        self._lmHead.wrappedValue = Linear(
            config.hiddenSize,
            config.vocabSize,
            bias: false
        )
    }
    
    public func callAsFunction(
        _ x: MLXArray,
        cache: [(MLXArray, MLXArray)]? = nil
    ) -> (MLXArray, [(MLXArray, MLXArray)]) {
        var mask: MLXArray? = nil
        if x.dim(1) > 1 {
            mask = MultiHeadAttention.createAdditiveCausalMask(x.dim(1))
            mask = mask?.asType(x.dtype)
        }
        
        let (y, cache) = model(x, mask: mask, cache: cache)
        return (lmHead(y), cache)
    }
}

public struct StableLMConfiguration: Codable {
    public var vocabSize: Int
    public var hiddenSize: Int
    public var attentionHeads: Int
    public var numHiddenLayers: Int
    public var kvHeads: Int
    public var partialRotaryFactor: Float
    public var intermediateSize: Int
    public var layerNormEps: Float
    public var ropeTheta: Float
    public var useQKVBias: Bool
    
    public init(
        vocabSize: Int,
        hiddenSize: Int,
        attentionHeads: Int,
        numHiddenLayers: Int,
        numKeyValueHeads: Int,
        partialRotaryFactor: Float,
        intermediateSize: Int,
        layerNormEps: Float,
        ropeTheta: Float,
        useQKVBias: Bool
    ) {
        self.vocabSize = vocabSize
        self.hiddenSize = hiddenSize
        self.attentionHeads = attentionHeads
        self.numHiddenLayers = numHiddenLayers
        self.kvHeads = numKeyValueHeads
        self.partialRotaryFactor = partialRotaryFactor
        self.intermediateSize = intermediateSize
        self.layerNormEps = layerNormEps
        self.ropeTheta = ropeTheta
        self.useQKVBias = useQKVBias
    }
    
    enum CodingKeys: String, CodingKey {
        case vocabSize = "vocab_size"
        case hiddenSize = "hidden_size"
        case attentionHeads = "num_attention_heads"
        case numHiddenLayers = "num_hidden_layers"
        case kvHeads = "num_key_value_heads"
        case partialRotaryFactor = "partial_rotary_factor"
        case intermediateSize = "intermediate_size"
        case layerNormEps = "layer_norm_eps"
        case ropeTheta = "rope_theta"
        case useQKVBias = "use_qkv_bias"
    }
}
