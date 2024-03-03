//
// Copyright (c) Vatsal Manot
//

import Swift

extension String {
    func deletingPrefix(
        _ prefix: String
    ) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        
        return String(dropFirst(prefix.count))
    }
}
