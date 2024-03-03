//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUIX

struct ContentView: View {
    @EnvironmentObject var runner: LLMRunner
    
    @State private var isInspectorPresented: Bool = UserInterfaceIdiom.current == .mac
    
    var body: some View {
        NavigationStack {
            VStack {
                PromptAndCompletionView(
                    prompt:  $runner.prompt,
                    completionText: runner.completionText
                )
            }
            .padding()
        }
        .navigationTitle("")
        .inspector(isPresented: $isInspectorPresented) {
            ConfigurationView()
                .inspectorColumnWidth(min: 256, ideal: 280, max: 320)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                HStack {
                    Image("mlx-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(4, style: .continuous)
                        .shadow(radius: 4)
                    
                    Text("MLX Swift")
                        .font(.title)
                }
                .padding(.horizontal)
            }
            ToolbarItemGroup {
                RunButton()
                
                toggleInspector
            }
        }
    }
    
    var toggleInspector: some View {
        Button {
            withAnimation {
                isInspectorPresented.toggle()
            }
        } label: {
            Label("Settings", systemImage: .gearshape)
        }
        .accessibilityLabel("Toggle Inspector")
    }
}

extension ContentView {
    private struct RunButton: View {
        @EnvironmentObject var runner: LLMRunner
        
        @ViewBuilder
        var body: some View {
            HStack(spacing: 4) {
                Button(action: runner.run) {
                    Label("Run", systemImage: .playFill)
                }
                .keyboardShortcut("r")
                .disabled(!(runner.status == .ready || runner.status == .failed))
                .accessibilityLabel("Run")

                switch runner.status {
                    case .noModelSelected:
                        EmptyView()
                    case .loadingModel:
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 6)
                    case .ready, .failed:
                        EmptyView()
                    case .generating(let progress):
                        ProgressView(
                            value: progress
                        )
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                        .padding(.trailing, 6)
                }
            }
        }
    }
}

struct PromptAndCompletionView: View {
    @Binding var prompt: String
    
    var completionText: AttributedString?
    
    var body: some View {
        VStack {
            GroupBox {
                promptEditor
                    .frame(height: 100, alignment: .topLeading)
                    .padding(.bottom, 16)
            } label: {
                Text("Prompt:")
                    .font(.headline)
            }
            
            GroupBox {
                ScrollView {
                    completionTextView
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding()
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: 512)
            } label: {
                Text("Completion:")
                    .font(.headline)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    var promptEditor: some View {
        TextView(text: $prompt)
            .font(.body)
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .multilineTextAlignment(.leading)
            .padding(.all, 8)
    }
    
    var completionTextView: some View {
        Text(completionText ?? "")
            .font(.system(size: 14))
            .foregroundColor(.blue)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}
