import PhotosUI
import SwiftUI
import UIKit

struct ImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTool: ImageEditorTool = .importImage
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var renderedImage: UIImage?
    @State private var parameters = ImageEditingParameters.default
    @State private var isLoadingImage = false
    @State private var isRenderingImage = false
    @State private var isSavingImage = false
    @State private var statusMessage = "等待导入图片"
    @State private var renderTask: Task<Void, Never>?

    private var displayedImage: UIImage? {
        renderedImage ?? sourceImage
    }

    private var imageStatus: String {
        sourceImage == nil ? "未导入" : "已就绪"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.055),
                        Color(red: 0.11, green: 0.105, blue: 0.095),
                        Color(red: 0.06, green: 0.06, blue: 0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    editorTopBar
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    imageStage
                        .padding(.horizontal, 18)

                    toolStrip
                        .padding(.top, 14)

                    selectedToolPanel
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    await loadSelectedPhoto(item)
                }
            }
            .onChange(of: parameters) { _, _ in
                scheduleRender()
            }
            .onDisappear {
                renderTask?.cancel()
            }
        }
    }

    private var editorTopBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(EditorIconButtonStyle())
                .accessibilityLabel("关闭图片编辑")

                VStack(alignment: .leading, spacing: 3) {
                    Text("图片编辑")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(ReceiptStyle.panel)
                    Text("IMAGE STUDIO")
                        .font(ReceiptStyle.mono(11, weight: .black))
                        .foregroundStyle(ReceiptStyle.panel.opacity(0.58))
                }

                Spacer()

                Button {
                    parameters = .default
                    statusMessage = "已还原编辑参数"
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .black))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(EditorIconButtonStyle())
                .disabled(sourceImage == nil || !parameters.hasEdits)
                .opacity(sourceImage == nil || !parameters.hasEdits ? 0.42 : 1)
                .accessibilityLabel("还原编辑参数")
            }

            HStack(spacing: 8) {
                statusBadge(title: imageStatus, systemImage: sourceImage == nil ? "photo" : "checkmark.circle.fill")
                statusBadge(title: parameters.filter.title, systemImage: "camera.filters")
                if isRenderingImage {
                    statusBadge(title: "渲染中", systemImage: "wand.and.sparkles")
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var imageStage: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.44))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                CheckerboardPattern()
                    .opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(10)

                if let displayedImage {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .shadow(color: .black.opacity(0.34), radius: 18, y: 8)
                        .overlay(alignment: .center) {
                            cropGuide
                        }
                        .accessibilityLabel("图片预览")
                } else {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48, weight: .black))
                            VStack(spacing: 6) {
                                Text("导入一张图片")
                                    .font(.system(size: 21, weight: .black, design: .rounded))
                                Text("裁剪、调色、滤镜、旋转后保存新图")
                                    .font(ReceiptStyle.mono(12, weight: .bold))
                                    .foregroundStyle(ReceiptStyle.panel.opacity(0.58))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .foregroundStyle(ReceiptStyle.panel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingImage)
                    .padding(16)
                }

                VStack {
                    Spacer()
                    HStack {
                        Text(statusMessage)
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                            .font(ReceiptStyle.mono(12, weight: .black))
                            .foregroundStyle(ReceiptStyle.panel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.black.opacity(0.48), in: Capsule())
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: 300)
    }

    @ViewBuilder
    private var cropGuide: some View {
        if sourceImage != nil, parameters.crop != .original {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.4, dash: [7, 6]))
                .padding(30)
                .allowsHitTesting(false)
        }
    }

    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ImageEditorTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 17, weight: .black))
                                .frame(height: 19)
                            Text(tool.title)
                                .font(ReceiptStyle.mono(11, weight: .black))
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedTool == tool ? ReceiptStyle.ink : ReceiptStyle.panel.opacity(0.76))
                        .frame(width: 72, height: 58)
                        .background(
                            selectedTool == tool
                                ? ReceiptStyle.accent
                                : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(selectedTool == tool ? 0.0 : 0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private var selectedToolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            panelHeader

            switch selectedTool {
            case .importImage:
                importPanel
            case .adjust:
                adjustmentPanel
            case .filter:
                filterPanel
            case .crop:
                cropPanel
            case .transform:
                transformPanel
            case .export:
                exportPanel
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var panelHeader: some View {
        HStack {
            Label(selectedTool.panelTitle, systemImage: selectedTool.systemImage)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(ReceiptStyle.panel)

            Spacer()

            Text(selectedTool.receiptName)
                .font(ReceiptStyle.mono(11, weight: .black))
                .foregroundStyle(ReceiptStyle.panel.opacity(0.52))
        }
    }

    private var importPanel: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                primaryActionLabel(
                    title: isLoadingImage ? "正在读取图片..." : "从相册选择",
                    systemImage: "photo.on.rectangle"
                )
            }
            .disabled(isLoadingImage)

            editorNote("选择新图片会清空当前编辑参数，并重新生成预览。")
        }
    }

    private var adjustmentPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sliderRow(title: "亮度", value: $parameters.brightness, range: -0.35...0.35, displayValue: signedPercent(parameters.brightness))
            sliderRow(title: "对比", value: $parameters.contrast, range: 0.55...1.8, displayValue: String(format: "%.2f", parameters.contrast))
            sliderRow(title: "饱和", value: $parameters.saturation, range: 0...2, displayValue: String(format: "%.2f", parameters.saturation))

            compactActionButton(title: "重置调色", systemImage: "slider.horizontal.below.rectangle") {
                parameters.brightness = 0
                parameters.contrast = 1
                parameters.saturation = 1
                statusMessage = "调色已重置"
            }
            .disabled(sourceImage == nil)
            .opacity(sourceImage == nil ? 0.46 : 1)
        }
    }

    private var filterPanel: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(ImageFilterPreset.allCases) { filter in
                choiceButton(
                    title: filter.title,
                    isSelected: parameters.filter == filter,
                    systemImage: filter == .original ? "circle" : "camera.filters"
                ) {
                    parameters.filter = filter
                    statusMessage = "滤镜已切换为 \(filter.title)"
                }
            }
        }
    }

    private var cropPanel: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(ImageCropPreset.allCases) { crop in
                choiceButton(
                    title: crop.title,
                    isSelected: parameters.crop == crop,
                    systemImage: crop == .original ? "viewfinder" : "crop"
                ) {
                    parameters.crop = crop
                    statusMessage = "裁剪比例已切换为 \(crop.title)"
                }
            }
        }
    }

    private var transformPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                compactActionButton(title: "左转", systemImage: "rotate.left") {
                    parameters.rotation = parameters.rotation.nextCounterClockwise
                    statusMessage = "图片已左转"
                }

                compactActionButton(title: "右转", systemImage: "rotate.right") {
                    parameters.rotation = parameters.rotation.nextClockwise
                    statusMessage = "图片已右转"
                }
            }

            HStack(spacing: 10) {
                compactActionButton(
                    title: parameters.isFlippedHorizontally ? "取消水平" : "水平镜像",
                    systemImage: "arrow.left.and.right"
                ) {
                    parameters.isFlippedHorizontally.toggle()
                    statusMessage = parameters.isFlippedHorizontally ? "已开启水平镜像" : "已取消水平镜像"
                }

                compactActionButton(
                    title: parameters.isFlippedVertically ? "取消垂直" : "垂直镜像",
                    systemImage: "arrow.up.and.down"
                ) {
                    parameters.isFlippedVertically.toggle()
                    statusMessage = parameters.isFlippedVertically ? "已开启垂直镜像" : "已取消垂直镜像"
                }
            }
        }
        .disabled(sourceImage == nil)
        .opacity(sourceImage == nil ? 0.46 : 1)
    }

    private var exportPanel: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await saveImage()
                }
            } label: {
                primaryActionLabel(
                    title: isSavingImage ? "正在保存..." : "保存到相册",
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(.plain)
            .disabled(displayedImage == nil || isSavingImage)
            .opacity(displayedImage == nil || isSavingImage ? 0.46 : 1)

            editorNote("保存会生成一张新图片，不会覆盖原图。")
        }
    }

    private func statusBadge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(ReceiptStyle.mono(11, weight: .black))
            .foregroundStyle(ReceiptStyle.panel.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func editorNote(_ text: String) -> some View {
        Text(text)
            .font(ReceiptStyle.mono(12, weight: .bold))
            .foregroundStyle(ReceiptStyle.panel.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, displayValue: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
            }
            .font(ReceiptStyle.mono(12, weight: .black))
            .foregroundStyle(ReceiptStyle.panel)

            Slider(value: value, in: range)
                .tint(ReceiptStyle.accent)
                .disabled(sourceImage == nil)
        }
    }

    private func choiceButton(title: String, isSelected: Bool, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .black))
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(ReceiptStyle.mono(12, weight: .black))
            .foregroundStyle(isSelected ? ReceiptStyle.ink : ReceiptStyle.panel)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(isSelected ? ReceiptStyle.accent : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(isSelected ? 0 : 0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(sourceImage == nil)
        .opacity(sourceImage == nil ? 0.46 : 1)
    }

    private func compactActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(ReceiptStyle.mono(12, weight: .black))
            .foregroundStyle(ReceiptStyle.panel)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func primaryActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(ReceiptStyle.mono(13, weight: .black))
        .foregroundStyle(ReceiptStyle.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(ReceiptStyle.accent, in: RoundedRectangle(cornerRadius: 14))
    }

    private func signedPercent(_ value: Double) -> String {
        let percent = Int((value * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    @MainActor
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingImage = true
        statusMessage = "正在读取图片"
        defer {
            isLoadingImage = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                statusMessage = "无法读取这张图片"
                return
            }

            renderTask?.cancel()
            sourceImage = image
            parameters = .default
            renderedImage = await ImageEditingService.renderedImageAsync(from: image, parameters: .default)
            statusMessage = "图片已导入"
        } catch {
            statusMessage = "图片读取失败，请换一张再试"
        }
    }

    private func scheduleRender() {
        renderTask?.cancel()
        guard let sourceImage else {
            renderedImage = nil
            isRenderingImage = false
            return
        }

        let currentParameters = parameters
        renderTask = Task { @MainActor in
            isRenderingImage = true
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else {
                isRenderingImage = false
                return
            }
            let image = await ImageEditingService.renderedImageAsync(from: sourceImage, parameters: currentParameters)
            guard !Task.isCancelled else {
                isRenderingImage = false
                return
            }
            renderedImage = image
            isRenderingImage = false
        }
    }

    @MainActor
    private func saveImage() async {
        guard let sourceImage else {
            statusMessage = "请先导入图片"
            return
        }

        isSavingImage = true
        statusMessage = "正在保存图片"
        defer {
            isSavingImage = false
        }

        do {
            renderTask?.cancel()
            let outputImage = await ImageEditingService.renderedImageAsync(from: sourceImage, parameters: parameters)
            renderedImage = outputImage
            try await ImageLibraryWriter.saveToPhotoLibrary(outputImage)
            statusMessage = "已保存到相册"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

private struct CheckerboardPattern: View {
    var body: some View {
        GeometryReader { proxy in
            let tileSize: CGFloat = 16
            let columns = max(Int(ceil(proxy.size.width / tileSize)), 1)
            let rows = max(Int(ceil(proxy.size.height / tileSize)), 1)

            Canvas { context, _ in
                for row in 0..<rows {
                    for column in 0..<columns where (row + column).isMultiple(of: 2) {
                        let rect = CGRect(
                            x: CGFloat(column) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        context.fill(Path(rect), with: .color(Color.white.opacity(0.18)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct EditorIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ReceiptStyle.panel)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private enum ImageEditorTool: CaseIterable {
    case importImage
    case adjust
    case filter
    case crop
    case transform
    case export

    var title: String {
        switch self {
        case .importImage:
            return "导入"
        case .adjust:
            return "调色"
        case .filter:
            return "滤镜"
        case .crop:
            return "裁剪"
        case .transform:
            return "方向"
        case .export:
            return "导出"
        }
    }

    var panelTitle: String {
        switch self {
        case .importImage:
            return "导入图片"
        case .adjust:
            return "基础调色"
        case .filter:
            return "滤镜预设"
        case .crop:
            return "画幅裁剪"
        case .transform:
            return "旋转镜像"
        case .export:
            return "导出结果"
        }
    }

    var receiptName: String {
        switch self {
        case .importImage:
            return "IMPORT"
        case .adjust:
            return "ADJUST"
        case .filter:
            return "FILTER"
        case .crop:
            return "CROP"
        case .transform:
            return "TRANSFORM"
        case .export:
            return "EXPORT"
        }
    }

    var systemImage: String {
        switch self {
        case .importImage:
            return "photo.badge.plus"
        case .adjust:
            return "slider.horizontal.3"
        case .filter:
            return "camera.filters"
        case .crop:
            return "crop"
        case .transform:
            return "rotate.right"
        case .export:
            return "square.and.arrow.down"
        }
    }
}

#Preview {
    ImageEditorView()
}
