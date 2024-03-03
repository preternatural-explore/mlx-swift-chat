//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUIX

struct ConfigurationView: View {
    @AppStorage("HuggingFaceToken") var huggingFaceToken: String = ""
    
    @EnvironmentObject var runner: LLMRunner
    
    @SceneStorage("isModelsViewPresented") var isModelsViewPresented: Bool = false
    
    var body: some View {
        VStack {
            Form {
                CompletionParametersView(
                    configuration: $runner.configuration.withDefaultValue(.init(maxNewTokens: 0)),
                    model: runner.llm
                )
                .disabled(runner.configuration == nil)
                
                manageModelsButton
                    .frame(width: .greedy)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.zero)
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .contentShape(Rectangle())
            }
            .formStyle(.automatic)
            .scrollBounceBehavior(.basedOnSize)
            
            Divider()
            
            StatusView(status: runner.status)
        }
        .padding(.bottom, .small)
    }
    
    private var huggingFaceTokenField: some View {
        Section {
            SecureField(
                "",
                text: $huggingFaceToken,
                prompt: Text("Enter your HuggingFace token here...")
            )
        } header: {
            Text("Hugging Face")
                .foregroundStyle(.secondary)
        }
    }
    
    private var manageModelsButton: some View {
        PresentationLink(isPresented: $isModelsViewPresented) {
            ModelsView()
        } label: {
            Text("Manage Models")
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }
}
