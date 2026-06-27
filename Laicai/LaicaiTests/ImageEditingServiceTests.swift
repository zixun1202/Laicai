import CoreGraphics
import UIKit
import XCTest
@testable import Laicai

final class ImageEditingServiceTests: XCTestCase {
    func testSquareCropCentersLandscapeImage() {
        let rect = ImageEditingService.cropRect(
            for: CGSize(width: 400, height: 200),
            preset: .square
        )

        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 200)
        XCTAssertEqual(rect.height, 200)
    }

    func testPortraitCropCentersWideImage() {
        let rect = ImageEditingService.cropRect(
            for: CGSize(width: 1000, height: 1000),
            preset: .portrait4x5
        )

        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.origin.y, 0)
        XCTAssertEqual(rect.width, 800)
        XCTAssertEqual(rect.height, 1000)
    }

    func testLandscapeCropCentersTallImage() {
        let rect = ImageEditingService.cropRect(
            for: CGSize(width: 900, height: 1600),
            preset: .landscape16x9
        )

        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 546.875, accuracy: 0.001)
        XCTAssertEqual(rect.width, 900, accuracy: 0.001)
        XCTAssertEqual(rect.height, 506.25, accuracy: 0.001)
    }

    func testStoryCropCentersWideImage() {
        let rect = ImageEditingService.cropRect(
            for: CGSize(width: 900, height: 900),
            preset: .story9x16
        )

        XCTAssertEqual(rect.origin.x, 196.875, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.001)
        XCTAssertEqual(rect.width, 506.25, accuracy: 0.001)
        XCTAssertEqual(rect.height, 900, accuracy: 0.001)
    }

    func testZeroSizedCropReturnsInputSize() {
        let rect = ImageEditingService.cropRect(
            for: .zero,
            preset: .square
        )

        XCTAssertEqual(rect, .zero)
    }

    func testOriginalCropKeepsFullImage() {
        let rect = ImageEditingService.cropRect(
            for: CGSize(width: 300, height: 500),
            preset: .original
        )

        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 300, height: 500))
    }

    func testDefaultParametersReportNoEdits() {
        XCTAssertFalse(ImageEditingParameters.default.hasEdits)

        var parameters = ImageEditingParameters.default
        parameters.filter = .mono

        XCTAssertTrue(parameters.hasEdits)
    }

    func testEveryParameterReportsEdits() {
        var parameters = ImageEditingParameters.default
        parameters.crop = .square
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.brightness = 0.1
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.contrast = 1.1
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.saturation = 0.8
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.rotation = .right
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.isFlippedHorizontally = true
        XCTAssertTrue(parameters.hasEdits)

        parameters = .default
        parameters.isFlippedVertically = true
        XCTAssertTrue(parameters.hasEdits)
    }

    func testRotationCyclesAndAxisSwapping() {
        XCTAssertEqual(ImageRotation.none.nextClockwise, .right)
        XCTAssertEqual(ImageRotation.right.nextClockwise, .upsideDown)
        XCTAssertEqual(ImageRotation.upsideDown.nextClockwise, .left)
        XCTAssertEqual(ImageRotation.left.nextClockwise, .none)

        XCTAssertEqual(ImageRotation.none.nextCounterClockwise, .left)
        XCTAssertFalse(ImageRotation.none.swapsAxes)
        XCTAssertTrue(ImageRotation.right.swapsAxes)
        XCTAssertTrue(ImageRotation.left.swapsAxes)
    }

    func testRenderedImageAppliesSquareCrop() {
        var parameters = ImageEditingParameters.default
        parameters.crop = .square

        let image = ImageEditingService.renderedImage(
            from: Self.makeImage(size: CGSize(width: 40, height: 20)),
            parameters: parameters
        )

        XCTAssertEqual(image.size.width, 20, accuracy: 0.001)
        XCTAssertEqual(image.size.height, 20, accuracy: 0.001)
        XCTAssertEqual(image.imageOrientation, .up)
    }

    func testRenderedImageRotatesBeforeCropping() {
        var parameters = ImageEditingParameters.default
        parameters.rotation = .right
        parameters.crop = .story9x16

        let image = ImageEditingService.renderedImage(
            from: Self.makeImage(size: CGSize(width: 40, height: 20)),
            parameters: parameters
        )

        XCTAssertEqual(image.size.width, 20, accuracy: 0.001)
        XCTAssertEqual(image.size.height, 36, accuracy: 0.001)
    }

    func testRenderedImageFlipKeepsSize() {
        var parameters = ImageEditingParameters.default
        parameters.isFlippedHorizontally = true
        parameters.isFlippedVertically = true

        let image = ImageEditingService.renderedImage(
            from: Self.makeImage(size: CGSize(width: 40, height: 20)),
            parameters: parameters
        )

        XCTAssertEqual(image.size.width, 40, accuracy: 0.001)
        XCTAssertEqual(image.size.height, 20, accuracy: 0.001)
    }

    func testSaveErrorDescriptionsAreReadable() {
        XCTAssertEqual(ImageSaveError.notAuthorized.localizedDescription, "没有相册写入权限")
        XCTAssertEqual(ImageSaveError.saveFailed.localizedDescription, "保存图片失败")
    }

    private static func makeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
