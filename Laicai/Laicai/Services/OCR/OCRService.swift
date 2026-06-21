import Foundation
import UIKit
import Vision

protocol OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String
}

struct OCRService: OCRServiceProtocol {
    func recognizeText(from image: UIImage) async throws -> String {
        ""
    }
}
