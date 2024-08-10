//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUIX
import UniformTypeIdentifiers

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
                        .font(.title3)
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
    @State var isHoveringOverPromptControls: Bool = false
    @State var isHoveringOverGenerationControls: Bool = false
    
    var completionText: AttributedString?
    
    var body: some View {
        VStack {
            GroupBox {
                promptEditor
                    .frame(height: 100, alignment: .topLeading)
                    .padding(.bottom, 16)
                promptControls
            } label: {
                Text("Prompt:")
                    .font(.headline)
            }
            
            GroupBox {
                ZStack {
                    ScrollView {
                        completionTextView
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding()
                    }
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: 512)
                    generationControls
                }
            } label: {
                Text("Completion:")
                    .font(.headline)
            }
        }
        .scrollIndicators(.hidden)
    }
    
    var promptEditor: some View {
        ZStack {
            TextView(text: $prompt)
                .font(.body)
                .fontDesign(.rounded)
                .scrollContentBackground(.hidden)
                .multilineTextAlignment(.leading)
                .padding(.all, 8)
        }
    }
    
    var promptControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                // copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prompt, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy the prompt")
                // remove button
                Button {
                    prompt = ""
                } label: {
                    Image(systemName: "clear")
                }
                .buttonStyle(.plain)
                .help("Clear the prompt field")
            }
            .padding(5)
            .opacity(isHoveringOverPromptControls ? 0.8 : 0.05)
            .offset(x: isHoveringOverPromptControls ? -5 : -10)
            .onHover(perform: { hovering in
                isHoveringOverPromptControls = hovering
            })
            .animation(.default, value: isHoveringOverPromptControls)
        }
    }
    
    var generationControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                // copy button
                Button {
                    if let text = completionText {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(String(text.characters), forType: .string)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy the generated text")
                // remove button
                Button {
                    if let text = completionText {
                        prompt = String(text.characters)
                    }
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .buttonStyle(.plain)
                .help("Send the generated text to prompt")
            }
            .padding(5)
            .opacity(isHoveringOverGenerationControls ? 0.8 : 0.05)
            .offset(x: isHoveringOverGenerationControls ? -5 : -10)
            .onHover(perform: { hovering in
                isHoveringOverGenerationControls = hovering
            })
            .animation(.default, value: isHoveringOverGenerationControls)
        }
    }
    
    var completionTextView: some View {
        Text(completionText ?? "")
            .font(.system(size: 14))
            .foregroundColor(.blue)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
