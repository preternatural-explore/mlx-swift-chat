//
// Copyright (c) Vatsal Manot
//

import CompactSlider
import MLXLLM
import SwiftUIX

struct CompletionParametersView: View {
    @EnvironmentObject var runner: LLMRunner
    
    @StateObject var modelStore = ModelStore.shared
    
    @Binding var configuration: GenerationConfig
    
    let model: RunnableLLM?
    
    @State private var showFilePicker = false
    
    var body: some View {
        Group {
            parametersSection
            toggleSamplingControl
            modelSelector
        }
    }
    
    private var parametersSection: some View {
        Section {
            temperatureControl
            topKControl
            maxTokensControl
        } header: {
            HStack {
                Label(
                    "Parameters",
                    systemImage: "slider.horizontal.3"
                )
                .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private var toggleSamplingControl: some View {
        HStack {
            Toggle(isOn: $configuration.doSample) {
                Text(
                    "Sample"
                )
            }
            
            Spacer()
        }
    }
    
    private var topKControl: some View {
        CompactSlider(value: Binding {
            CFloat(configuration.topK)
        } set: {
            configuration.topK = Int($0)
        }, in: 1...50, step: 1) {
            Text("Top K")
            Spacer()
            Text("\(configuration.topK)")
        }
        .compactSliderSecondaryColor(.blue)
        .disabled(!configuration.doSample)
        .help(
            "Sort predicted tokens by probability and discards those below the k-th one. A top-k value of 1 is equivalent to greedy search (select the most probable token)"
        )
    }
    
    private var temperatureControl: some View {
        CompactSlider(value: $configuration.temperature, in: 0...2, direction: .center) {
            Text("Temperature")
            Spacer()
            Text("\(configuration.temperature, specifier: "%.2f")")
        }
        .compactSliderStyle(
            .prominent(
                lowerColor: .blue,
                upperColor: .red,
                useGradientBackground: true
            )
        )
        .compactSliderSecondaryColor(configuration.temperature <= 0.5 ? .blue : .red)
        .disabled(!configuration.doSample)
        .help(
            "Controls randomness: Lowering results in less random completions. As the temperature approaches zero, the model will become deterministic and repetitive."
        )
    }
    
    @ViewBuilder
    private var maxTokensControl: some View {
        CompactSlider(
            value: Binding {
                CFloat(configuration.maxNewTokens)
            } set: {
                configuration.maxNewTokens = Int($0)
            },
            in: CFloat(1)...100000, // FIXME:
            step: 1
        ) {
            Text("Maximum length")
            
            Spacer()
            
            Text("\(Int(configuration.maxNewTokens))")
        }
        .compactSliderSecondaryColor(.blue)
        .help(
            "The maximum number of tokens to generate. Requests can use up to 2,048 tokens shared between prompt and completion. The exact limit varies by model. (One token is roughly 4 characters for normal English text)"
        )
    }
    
    private var modelSelector: some View {
        Section {
            Picker("Model", selection: $runner.model) {
                ForEach(modelStore.models) { model in
                    Text(model.displayName)
                        .tag(Optional.some(model.id))
                }
                
                Text("No Selection")
                    .foregroundStyle(.secondary)
                    .tag(Optional<ModelStore.Model.ID>.none)
            }
            .padding(.vertical, .extraSmall)
        } header: {
            HStack {
                Label("Model", systemImage: .oven)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
}
