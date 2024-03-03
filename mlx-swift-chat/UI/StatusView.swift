//
// Copyright (c) Vatsal Manot
//

import MLXLLM
import SwiftUI

struct StatusView: View {
    let status: LLMRunnerStatus
        
    var body: some View {
        switch status {
            case .noModelSelected:
                Text("No Model Selected")
                    .font(.body)
                    .frame(height: 50)
                    .foregroundStyle(.secondary)
            case .loadingModel:
                HStack(spacing: 4) {
                    Text("Loading model...")
                        .frame(height: 50)
                    
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            case .generating(let progress):
                let label = progress > 0 ? "Generating..." : "Preparing..."
                
                ProgressView(
                    label,
                    value: progress,
                    total: 1
                )
                .padding()
                .frame(height: 50)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.gray))
            case .ready(let tps):
                if let tps = tps {
                    HStack {
                        Spacer()
                        
                        Text("Ready")
                        
                        Spacer()
                        
                        if floor(tps) != 0 {
                            Text("\(tps, specifier: "%.2f") tokens/s")
                                .padding(.trailing)
                        }
                    }
                    .frame(height: 50)
                } else {
                    Text("Ready")
                        .frame(height: 50)
                }
            case .failed(let errorMessage):
                Text("Error: \(errorMessage)")
                    .font(.body)
                    .foregroundStyle(.red)
                    .frame(height: 50)
        }
    }
}
