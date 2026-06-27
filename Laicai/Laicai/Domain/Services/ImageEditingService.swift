import CoreImage
import Photos
import UIKit

struct ImageEditingParameters: Equatable {
    var filter: ImageFilterPreset = .original
    var crop: ImageCropPreset = .original
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var rotation: ImageRotation = .none
    var isFlippedHorizontally = false
    var isFlippedVertically = false

    static let `default` = ImageEditingParameters()

    var hasEdits: Bool {
        self != .default
    }
}

enum ImageFilterPreset: String, CaseIterable, Identifiable {
    case original
    case vivid
    case mono
    case warm
    case fade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原图"
        case .vivid:
            return "鲜明"
        case .mono:
            return "黑白"
        case .warm:
            return "暖调"
        case .fade:
            return "褪色"
        }
    }

    var receiptName: String {
        switch self {
        case .original:
            return "ORIGINAL"
        case .vivid:
            return "VIVID"
        case .mono:
            return "MONO"
        case .warm:
            return "WARM"
        case .fade:
            return "FADE"
        }
    }
}

enum ImageCropPreset: String, CaseIterable, Identifiable {
    case original
    case square
    case portrait4x5
    case story9x16
    case landscape16x9

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原始"
        case .square:
            return "1:1"
        case .portrait4x5:
            return "4:5"
        case .story9x16:
            return "9:16"
        case .landscape16x9:
            return "16:9"
        }
    }

    var receiptName: String {
        switch self {
        case .original:
            return "ORIGINAL"
        case .square:
            return "SQUARE"
        case .portrait4x5:
            return "PORTRAIT"
        case .story9x16:
            return "STORY"
        case .landscape16x9:
            return "LANDSCAPE"
        }
    }

    var aspectRatio: CGFloat? {
        switch self {
        case .original:
            return nil
        case .square:
            return 1
        case .portrait4x5:
            return 4 / 5
        case .story9x16:
            return 9 / 16
        case .landscape16x9:
            return 16 / 9
        }
    }
}

enum ImageRotation: Int, CaseIterable, Identifiable {
    case none = 0
    case right = 90
    case upsideDown = 180
    case left = 270

    var id: Int { rawValue }

    var receiptName: String {
        "\(rawValue) DEG"
    }

    var nextClockwise: ImageRotation {
        switch self {
        case .none:
            return .right
        case .right:
            return .upsideDown
        case .upsideDown:
            return .left
        case .left:
            return .none
        }
    }

    var nextCounterClockwise: ImageRotation {
        switch self {
        case .none:
            return .left
        case .left:
            return .upsideDown
        case .upsideDown:
            return .right
        case .right:
            return .none
        }
    }

    var swapsAxes: Bool {
        self == .left || self == .right
    }
}

enum ImageSaveError: LocalizedError {
    case notAuthorized
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "没有相册写入权限"
        case .saveFailed:
            return "保存图片失败"
        }
    }
}

enum ImageEditingService {
    private static let context = CIContext()

    static func renderedImage(from sourceImage: UIImage, parameters: ImageEditingParameters) -> UIImage {
        let normalizedSource = normalized(image: sourceImage)
        let transformedSource = transformedImage(normalizedSource, parameters: parameters)

        guard var ciImage = CIImage(image: transformedSource) else {
            return transformedSource
        }

        ciImage = croppedImage(ciImage, preset: parameters.crop)
        ciImage = colorControlledImage(ciImage, parameters: parameters)
        ciImage = filteredImage(ciImage, preset: parameters.filter)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return transformedSource
        }

        return UIImage(cgImage: cgImage, scale: transformedSource.scale, orientation: .up)
    }

    static func renderedImageAsync(from sourceImage: UIImage, parameters: ImageEditingParameters) async -> UIImage {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderedImage = renderedImage(from: sourceImage, parameters: parameters)
                continuation.resume(returning: renderedImage)
            }
        }
    }

    static func cropRect(for imageSize: CGSize, preset: ImageCropPreset) -> CGRect {
        guard let aspectRatio = preset.aspectRatio,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }

        let currentRatio = imageSize.width / imageSize.height
        if currentRatio > aspectRatio {
            let targetWidth = imageSize.height * aspectRatio
            return CGRect(
                x: (imageSize.width - targetWidth) / 2,
                y: 0,
                width: targetWidth,
                height: imageSize.height
            )
        }

        let targetHeight = imageSize.width / aspectRatio
        return CGRect(
            x: 0,
            y: (imageSize.height - targetHeight) / 2,
            width: imageSize.width,
            height: targetHeight
        )
    }

    private static func croppedImage(_ image: CIImage, preset: ImageCropPreset) -> CIImage {
        let cropRect = cropRect(for: image.extent.size, preset: preset)
            .offsetBy(dx: image.extent.origin.x, dy: image.extent.origin.y)
            .integral

        return image.cropped(to: cropRect)
    }

    private static func colorControlledImage(_ image: CIImage, parameters: ImageEditingParameters) -> CIImage {
        guard let colorControls = CIFilter(name: "CIColorControls") else {
            return image
        }

        colorControls.setValue(image, forKey: kCIInputImageKey)
        colorControls.setValue(parameters.brightness, forKey: kCIInputBrightnessKey)
        colorControls.setValue(parameters.contrast, forKey: kCIInputContrastKey)
        colorControls.setValue(parameters.saturation, forKey: kCIInputSaturationKey)
        return colorControls.outputImage ?? image
    }

    private static func filteredImage(_ image: CIImage, preset: ImageFilterPreset) -> CIImage {
        switch preset {
        case .original:
            return image
        case .vivid:
            guard let filter = CIFilter(name: "CIVibrance") else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.85, forKey: "inputAmount")
            return filter.outputImage ?? image
        case .mono:
            guard let filter = CIFilter(name: "CIPhotoEffectNoir") else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage ?? image
        case .warm:
            guard let filter = CIFilter(name: "CISepiaTone") else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(0.45, forKey: kCIInputIntensityKey)
            return filter.outputImage ?? image
        case .fade:
            guard let filter = CIFilter(name: "CIPhotoEffectFade") else { return image }
            filter.setValue(image, forKey: kCIInputImageKey)
            return filter.outputImage ?? image
        }
    }

    private static func normalized(image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func transformedImage(_ image: UIImage, parameters: ImageEditingParameters) -> UIImage {
        guard parameters.rotation != .none || parameters.isFlippedHorizontally || parameters.isFlippedVertically else {
            return image
        }

        let targetSize = parameters.rotation.swapsAxes
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            cgContext.rotate(by: CGFloat(parameters.rotation.rawValue) * .pi / 180)

            cgContext.scaleBy(
                x: parameters.isFlippedHorizontally ? -1 : 1,
                y: parameters.isFlippedVertically ? -1 : 1
            )

            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }
}

enum ImageLibraryWriter {
    static func saveToPhotoLibrary(_ image: UIImage) async throws {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw ImageSaveError.notAuthorized
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                success
                    ? continuation.resume(returning: ())
                    : continuation.resume(throwing: ImageSaveError.saveFailed)
            }
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
