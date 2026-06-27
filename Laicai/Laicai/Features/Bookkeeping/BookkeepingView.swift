import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct BookkeepingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DraftEntry.createdAt, order: .reverse) private var drafts: [DraftEntry]
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Query private var profiles: [UserProfile]
    @State private var selectedTool: BookkeepingTool = .manual
    @State private var presentedSheet: BookkeepingSheet?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingInput = false
    @State private var statusMessage: String?
    @State private var operationHistory = ["READY"]
    private let ocrService = OCRService()
    private let voiceService = VoiceRecognitionService()

    private var currencyCode: String {
        profiles.first?.defaultCurrency ?? "CNY"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 20) {
                        TicketPageHeader(title: "记账中心", subtitle: "QUICK ENTRY", systemImage: "square.and.pencil")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "QUEUE", value: "\(drafts.count) DRAFTS")
                            ReceiptInfoRow(label: "MODE", value: selectedTool.receiptName)
                            ReceiptInfoRow(label: "STATUS", value: drafts.isEmpty ? "CLEAR" : "WAITING")
                            ReceiptDashedDivider()
                        }

                        toolStrip
                        selectedToolPanel
                        statusLine

                        ReceiptSectionLabel(title: "待确认草稿")
                        draftQueue
                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "PENDING ITEMS", value: String(format: "%02d", drafts.count))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("记账小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .manualEntry:
                    ManualEntryView()
                case .imageEditor:
                    ImageEditorView()
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    await createDraft(from: item)
                }
            }
        }
    }

    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BookkeepingTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                        appendHistory("MODE \(tool.receiptName)")
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 17, weight: .bold))
                            Text(tool.title)
                                .font(ReceiptStyle.mono(11, weight: .bold))
                        }
                        .foregroundStyle(selectedTool == tool ? ReceiptStyle.paper : ReceiptStyle.ink)
                        .frame(width: 72, height: 56)
                        .background(selectedTool == tool ? ReceiptStyle.ink : Color.white.opacity(0.26), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ReceiptStyle.ink.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedToolPanel: some View {
        switch selectedTool {
        case .manual:
            toolPanel(
                title: "手工记一笔",
                note: "输入金额、类型和备注，直接打印到今日小票。",
                actionTitle: "打开手工录入",
                systemImage: "square.and.pencil"
            ) {
                presentedSheet = .manualEntry
                appendHistory("OPEN MANUAL")
            }
        case .voice:
            toolPanel(
                title: "语音录入",
                note: "听取一段语音并识别成待确认草稿，再确认入账。",
                actionTitle: isProcessingInput ? "正在听写..." : "开始语音记账",
                systemImage: "waveform"
            ) {
                Task {
                    await createVoiceDraft()
                }
            }
        case .screenshot:
            VStack(alignment: .leading, spacing: 12) {
                Text("截图录入")
                    .font(ReceiptStyle.mono(16, weight: .bold))
                Text("· 从账单截图识别金额和备注，先进入草稿队列。")
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    receiptPickerLabel(
                        title: isProcessingInput ? "正在识别截图..." : "选择账单截图",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .disabled(isProcessingInput)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .imageEdit:
            toolPanel(
                title: "图片工坊",
                note: "导入图片后裁剪、调色、套滤镜，再保存一张新图到相册。",
                actionTitle: "打开图片工坊",
                systemImage: "photo.on.rectangle.angled"
            ) {
                presentedSheet = .imageEditor
                appendHistory("OPEN IMAGE LAB")
            }
        case .review:
            VStack(alignment: .leading, spacing: 10) {
                Text("确认队列")
                    .font(ReceiptStyle.mono(16, weight: .bold))
                Text(drafts.isEmpty ? "· 暂无待确认草稿" : "· 点选下方草稿，核对后入账")
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .history:
            historyPanel
        }
    }

    private func toolPanel(
        title: String,
        note: String,
        actionTitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(ReceiptStyle.mono(16, weight: .bold))
            Text("· \(note)")
                .font(ReceiptStyle.mono(13, weight: .semibold))
                .foregroundStyle(ReceiptStyle.fadedInk)
            ReceiptActionButton(title: actionTitle, systemImage: systemImage, action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func receiptPickerLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .font(ReceiptStyle.mono(13, weight: .bold))
        .foregroundStyle(ReceiptStyle.paper)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusLine: some View {
        if let statusMessage {
            Text("· \(statusMessage)")
                .font(ReceiptStyle.mono(12, weight: .semibold))
                .foregroundStyle(ReceiptStyle.fadedInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var draftQueue: some View {
        if drafts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("暂无草稿")
                    .font(ReceiptStyle.mono(16, weight: .bold))
                Text("· 录入后会在这里排队，确认后写入今日小票")
                    .font(ReceiptStyle.mono(13, weight: .semibold))
                    .foregroundStyle(ReceiptStyle.fadedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 14) {
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    NavigationLink {
                        DraftConfirmationView(draft: draft)
                    } label: {
                        VStack(spacing: 12) {
                            HStack(alignment: .top) {
                                Text(String(format: "%02d", index + 1))
                                    .frame(width: 34, alignment: .leading)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(draft.note)
                                        .fontWeight(.bold)
                                    Text("· \(sourceLabel(draft.sourceType)) \(money(draft.amount, digits: 2))")
                                        .foregroundStyle(ReceiptStyle.fadedInk)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                            }
                            .font(ReceiptStyle.mono(14, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.ink)

                            if index < drafts.count - 1 {
                                ReceiptDashedDivider()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func createVoiceDraft() async {
        guard !isProcessingInput else { return }
        isProcessingInput = true
        statusMessage = "请说出金额和用途，例如“午饭 38”"
        appendHistory("VOICE LISTEN")
        defer {
            isProcessingInput = false
        }

        guard await voiceService.requestAuthorization() else {
            statusMessage = "语音或麦克风权限未开启"
            appendHistory("VOICE DENIED")
            return
        }

        do {
            let transcript = try await voiceService.transcribeOnce()
            insertDraftIfPossible(sourceType: "voice", originalText: transcript)
        } catch {
            statusMessage = "语音识别失败，请重试或改用手工录入"
            appendHistory("VOICE ERROR")
        }
    }

    private func createDraft(from item: PhotosPickerItem) async {
        guard !isProcessingInput else { return }
        isProcessingInput = true
        statusMessage = "正在读取截图并识别文字"
        appendHistory("SCREENSHOT READ")
        defer {
            isProcessingInput = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                statusMessage = "无法读取这张截图"
                appendHistory("SCREENSHOT ERROR")
                return
            }

            let recognizedText = try await ocrService.recognizeText(from: image)
            insertDraftIfPossible(sourceType: "screenshot", originalText: recognizedText)
        } catch {
            statusMessage = "截图识别失败，请换一张清晰账单"
            appendHistory("OCR ERROR")
        }
    }

    private func insertDraftIfPossible(sourceType: String, originalText: String) {
        guard let draft = DraftCreationService.createDraft(
            sourceType: sourceType,
            originalText: originalText
        ) else {
            statusMessage = "没有识别到金额，请补充数字后再试"
            appendHistory("NO AMOUNT")
            return
        }

        modelContext.insert(draft)
        do {
            try modelContext.save()
            statusMessage = "已生成待确认草稿：\(draft.note)"
            appendHistory("DRAFT \(sourceLabel(sourceType))")
        } catch {
            modelContext.rollback()
            statusMessage = "草稿保存失败，请稍后重试"
            appendHistory("SAVE ERROR")
        }
    }

    private func sourceLabel(_ sourceType: String) -> String {
        switch sourceType {
        case "voice":
            return "VOICE"
        case "screenshot":
            return "SCREENSHOT"
        default:
            return "MANUAL"
        }
    }

    private var operationStack: some View {
        VStack(spacing: 8) {
            ReceiptSectionLabel(title: "操作历史")
            ForEach(Array(operationHistory.suffix(4).enumerated()), id: \.offset) { index, item in
                ReceiptInfoRow(label: String(format: "%02d", index + 1), value: item)
            }
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易历史")
                .font(ReceiptStyle.mono(16, weight: .bold))
            Text(transactions.isEmpty ? "· 暂无已入账记录" : "· 最近交易已同步到本地账本")
                .font(ReceiptStyle.mono(13, weight: .semibold))
                .foregroundStyle(ReceiptStyle.fadedInk)

            if !transactions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(transactions.prefix(3).enumerated()), id: \.element.id) { index, transaction in
                        VStack(spacing: 10) {
                            ReceiptInfoRow(
                                label: String(format: "%02d %@", index + 1, transaction.type.displayName),
                                value: money(transaction.amount, digits: 2)
                            )
                            if index < min(transactions.count, 3) - 1 {
                                ReceiptDashedDivider()
                            }
                        }
                    }
                }
            }

            NavigationLink {
                TransactionHistoryView()
            } label: {
                receiptPickerLabel(title: "查看完整交易历史", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func money(_ value: Double, digits: Int = 0) -> String {
        CurrencyFormatterService.money(
            value,
            currencyCode: currencyCode,
            minimumFractionDigits: digits,
            maximumFractionDigits: digits
        )
    }

    private func appendHistory(_ item: String) {
        operationHistory.append(item)
    }
}

private enum BookkeepingTool: CaseIterable {
    case manual
    case voice
    case screenshot
    case imageEdit
    case review
    case history

    var title: String {
        switch self {
        case .manual:
            return "手工"
        case .voice:
            return "语音"
        case .screenshot:
            return "截图"
        case .imageEdit:
            return "图片"
        case .review:
            return "确认"
        case .history:
            return "历史"
        }
    }

    var receiptName: String {
        switch self {
        case .manual:
            return "MANUAL"
        case .voice:
            return "VOICE"
        case .screenshot:
            return "SCREENSHOT"
        case .imageEdit:
            return "IMAGE"
        case .review:
            return "REVIEW"
        case .history:
            return "HISTORY"
        }
    }

    var systemImage: String {
        switch self {
        case .manual:
            return "square.and.pencil"
        case .voice:
            return "waveform"
        case .screenshot:
            return "photo.on.rectangle"
        case .imageEdit:
            return "photo.on.rectangle.angled"
        case .review:
            return "checklist"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}

private enum BookkeepingSheet: Identifiable {
    case manualEntry
    case imageEditor

    var id: String {
        switch self {
        case .manualEntry:
            return "manual-entry"
        case .imageEditor:
            return "image-editor"
        }
    }
}
