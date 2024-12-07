//
//  ConfigurationError.swift
//  LightsOut
//
//

import Foundation
import CoreGraphics

struct DisplayError: Error, Identifiable {
    var id: String { UUID().uuidString }
    var msg: String
}
