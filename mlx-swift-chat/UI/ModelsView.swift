//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUIX

struct ModelsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.userInterfaceIdiom) var userInterfaceIdiom
    
    @ObservedObject var store = ModelStore.shared
    
    @State var isAddAlertPresented: Bool = false
    @State var url: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ZeroSizeView()
                        .frame(height: 1)
                        .listRowSeparator(.hidden)
                        .listSectionSeparator(.hidden)

                    Section("Suggestions") {
                        ForEach(store.suggestions) { suggestion in
                            SuggestionCell(suggestion: suggestion)
                        }
                    }

                    Section("Downloaded") {
                        ForEach(store.models) { model in
                            ModelCell(model: model)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding()
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem {
                    Button("Add Model") {
                        isAddAlertPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                ToolbarItem {
                    Button("Dismiss") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Add Model", isPresented: $isAddAlertPresented) {
            TextField("URL", text: $url, prompt: Text(
                "Enter the HuggingFace URL..."
            ))
            
            Button("Confirm") {
                addURL()
            }
            .disabled(url.isEmpty || URL(string: url) == nil)
            
            Button("Cancel") {
                url = ""
            }
        }
        .dialogIcon(Image("mlx-logo"))
        .onChange(of: isAddAlertPresented) {
            addURL()
        }
        .modify(for: .macOS) { content in
            content
                .frame(
                    minWidth: 512,
                    maxWidth: .infinity,
                    minHeight: 512,
                    maxHeight: .infinity,
                    alignment: .top
                )
        }
    }
    
    private func addURL() {
        if let url = URL(string: url) {
            store.accept(ModelStore.Suggestion(url: url))
            
            self.url = ""
        }
    }
}

extension ModelsView {
    struct SuggestionCell: View {
        @StateObject var store = ModelStore.shared
        
        let suggestion: ModelStore.Suggestion
        
        var body: some View {
            let isSuggestionUnavailable = store.containsModel(named: suggestion.name)
            
            Button {
                store.accept(suggestion)
            } label: {
                HStack {
                    Text(suggestion.name)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !isSuggestionUnavailable {
                        Image(systemName: .arrowDownCircle)
                            .font(.body)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isSuggestionUnavailable)
        }
    }
    
    struct ModelCell: View {
        private enum Subviews: Hashable {
            case stateDisclosure
        }
        
        @StateObject var store = ModelStore.shared
        
        let model: ModelStore.Model
        
        var body: some View {
            FrameReader { proxy in
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .font(.headline)
                            .lineLimit(1)
                            .padding(.trailing, proxy.size(for: Subviews.stateDisclosure)?.width)
                            .frame(minHeight: proxy.size(for: Subviews.stateDisclosure)?.height)

                        descriptionView
                        
                        progressBar
                    }
                    .frame(width: .greedy, alignment: .leading)
                    
                    stateDisclosure
                        .fixedSize()
                        .frame(id: Subviews.stateDisclosure)
                }
                .padding(.vertical, .small)
                .contextMenu {
                    Button(role: .destructive) {
                        store.delete(model.id)
                    } label: {
                        Text("Delete")
                    }
                }
            }
            .textSelection(.enabled)
        }
        
        @ViewBuilder
        private var descriptionView: some View {
            if let url = model.url {
#if os(macOS)
                PathControl(url: url)
                    .pathControlStyle(PopUpPathControlStyle())
#else
                Text(url.path())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
#endif
            }
        }
        
        @ViewBuilder
        private var stateDisclosure: some View {
            switch model.state {
                case .notDownloaded:
                    EmptyView()
                case .downloading:
                    EmptyView()
                case .downloaded:
                    Image(systemName: .arrowDownCircleFill)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .imageScale(.small)
                case .failed(let error):
                    PresentationLink {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Error Description:")
                                .font(.subheadline.uppercaseSmallCaps())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Color.label)
                                .frame(minWidth: 128, alignment: .topLeading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .textSelection(.enabled)
                        .padding(.small)
                        .frame(minHeight: 44, alignment: .top)
                    } label: {
                        Image(systemName: .exclamationmarkTriangle)
                            .font(.body)
                            .foregroundStyle(.red.secondary)
                    }
                    .presentationStyle(.popover)
                    .buttonStyle(.plain)
            }
        }
        
        @ViewBuilder
        private var progressBar: some View {
            switch model.state {
                case .downloading(let progress):
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                default:
                    EmptyView()
            }
        }
    }
}
