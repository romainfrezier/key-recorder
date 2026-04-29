//
//  RecordingConfig.swift
//  key-recorder
//
//  Created by Romain on 24.03.2026.
//

import Foundation
import CoreGraphics

struct RecordingConfig {
    let key1Name: String
    let key2Name: String
    let key1Display: String
    let key2Display: String
    let key1Code: CGKeyCode
    let key2Code: CGKeyCode
    let duration: TimeInterval
    let interval: TimeInterval
}
