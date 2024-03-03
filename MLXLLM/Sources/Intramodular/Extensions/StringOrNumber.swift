//
// Copyright (c) Vatsal Manot
//

import Swift

public enum StringOrNumber: Codable, Equatable {
    case string(String)
    case float(Float)
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()
        
        if let v = try? values.decode(Float.self) {
            self = .float(v)
        } else {
            let v = try values.decode(String.self)
            self = .string(v)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
            case .string(let v): try container.encode(v)
            case .float(let v): try container.encode(v)
        }
    }
}
