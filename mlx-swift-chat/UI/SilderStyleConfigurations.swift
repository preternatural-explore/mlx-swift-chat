//
//  SilderStyleConfigurations.swift
//  mlx-swift-chat
//
//  Created by ookamitai on 8/10/24.
//

import Foundation
import SwiftUI
import CompactSlider

public struct GeneralCompactSliderStyle: CompactSliderStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                configuration.isHovering || configuration.isDragging ? .primary : .primary.opacity(0.6)
            )
            .background (
                Color.accentColor.opacity(0.1)
            )
            .compactSliderSecondaryAppearance(
                progressShapeStyle: LinearGradient(
                    colors: [.accentColor.opacity(0.1), .accentColor.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                focusedProgressShapeStyle: LinearGradient(
                    colors: [.accentColor.opacity(0.2), .accentColor.opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .animation(.default, value: configuration.isHovering)
    }
}

public struct TemperatureCompactSliderStyle: CompactSliderStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(
                configuration.isHovering || configuration.isDragging ? .primary : .primary.opacity(0.6)
            )
            .background (
                LinearGradient(gradient: Gradient(colors: [.blue, .red]), startPoint: .leading, endPoint: .trailing)
                    .opacity(0.1)
            )
            .compactSliderStyle (
                .prominent(lowerColor: .blue, upperColor: .red, useGradientBackground: true)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .animation(.default, value: configuration.isHovering)
    }
}

public extension CompactSliderStyle where Self == GeneralCompactSliderStyle {
    static var `general`: GeneralCompactSliderStyle { GeneralCompactSliderStyle() }
}

public extension CompactSliderStyle where Self == TemperatureCompactSliderStyle {
    static var `temp`: TemperatureCompactSliderStyle { TemperatureCompactSliderStyle() }
}

