import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var assets: [Asset]
    @Query private var transactions: [TransactionRecord]
    @Query private var drafts: [DraftEntry]
    @State private var selectedCurrency = "CNY"
    @State private var confirmation: SettingsConfirmation?
    @State private var statusMessage: String?
    @State private var dataSheet: SettingsDataSheet?
    @State private var exportText = ""
    @State private var importText = ""
    @State private var replacingOnImport = true

    private let currencies = CurrencyFormatterService.supportedCurrencyCodes

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 20) {
                        TicketPageHeader(title: "本地设置", subtitle: "LOCAL FIRST", systemImage: "gearshape")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "CURRENCY", value: selectedCurrency)
                            ReceiptInfoRow(label: "STORAGE", value: "ON DEVICE")
                            ReceiptInfoRow(label: "PROCESS", value: "LOCAL")
                            ReceiptDashedDivider()
                        }

                        ReceiptSectionLabel(title: "默认设置")
                        pickerBlock(title: "默认币种") {
                            Picker("默认币种", selection: $selectedCurrency) {
                                ForEach(currencies, id: \.self) { currency in
                                    Text(currency).tag(currency)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        settingSection(title: "权限", rows: [
                            ("相册与截图识别", "用于生成草稿"),
                            ("麦克风与语音识别", "用于语音记账")
                        ])

                        settingSection(title: "本地数据", rows: [
                            ("资产条目", String(format: "%02d", assets.count)),
                            ("交易记录", String(format: "%02d", transactions.count)),
                            ("待确认草稿", String(format: "%02d", drafts.count))
                        ])

                        VStack(spacing: 10) {
                            ReceiptActionButton(title: "导出账本备份", systemImage: "square.and.arrow.up") {
                                prepareExport()
                            }
                            ReceiptActionButton(title: "导入账本备份", systemImage: "tray.and.arrow.down") {
                                importText = ""
                                replacingOnImport = true
                                dataSheet = .importBackup
                            }
                        }

                        settingSection(title: "隐私", rows: [
                            ("数据默认保存在本机", "不主动上传"),
                            ("截图与语音在本地处理", "先解析后确认")
                        ])

                        VStack(spacing: 10) {
                            ReceiptActionButton(title: "清空草稿队列", systemImage: "trash") {
                                confirmation = .clearDrafts
                            }
                            ReceiptActionButton(title: "重置本地账本", systemImage: "exclamationmark.triangle") {
                                confirmation = .resetLedger
                            }
                        }

                        if let statusMessage {
                            Text("· \(statusMessage)")
                                .font(ReceiptStyle.mono(12, weight: .semibold))
                                .foregroundStyle(ReceiptStyle.fadedInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ReceiptDashedDivider()
                        ReceiptInfoRow(label: "DATA MODE", value: "LOCAL ONLY")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("设置小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ReceiptStyle.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear(perform: loadProfile)
            .onChange(of: selectedCurrency) { _, currency in
                saveCurrency(currency)
            }
            .alert(item: $confirmation) { confirmation in
                Alert(
                    title: Text(confirmation.title),
                    message: Text(confirmation.message),
                    primaryButton: .destructive(Text(confirmation.actionTitle)) {
                        perform(confirmation)
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .sheet(item: $dataSheet) { sheet in
                switch sheet {
                case .exportBackup:
                    LedgerExportSheet(exportText: exportText)
                case .importBackup:
                    LedgerImportSheet(
                        importText: $importText,
                        replacingOnImport: $replacingOnImport,
                        onImport: importBackup
                    )
                }
            }
        }
    }

    private func settingSection(title: String, rows: [(String, String)]) -> some View {
        VStack(spacing: 12) {
            ReceiptSectionLabel(title: title)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(spacing: 10) {
                    ReceiptInfoRow(label: row.0, value: row.1)
                    if index < rows.count - 1 {
                        ReceiptDashedDivider()
                    }
                }
            }
        }
    }

    private func pickerBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ReceiptStyle.mono(13, weight: .bold))
            content()
                .padding(.vertical, 4)
        }
        .foregroundStyle(ReceiptStyle.ink)
    }

    private func loadProfile() {
        if let profile = profiles.first {
            selectedCurrency = profile.defaultCurrency
            return
        }

        let profile = makeProfile()
        selectedCurrency = profile.defaultCurrency
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            statusMessage = "默认设置初始化失败"
        }
    }

    private func saveCurrency(_ currency: String) {
        let profile = profiles.first ?? makeProfile()
        guard profile.defaultCurrency != currency else { return }
        profile.defaultCurrency = currency
        do {
            try modelContext.save()
            statusMessage = "默认币种已保存为 \(currency)"
        } catch {
            modelContext.rollback()
            statusMessage = "默认币种保存失败"
        }
    }

    private func makeProfile() -> UserProfile {
        let profile = UserProfile(defaultCurrency: selectedCurrency, onboardingCompleted: true)
        modelContext.insert(profile)
        return profile
    }

    private func prepareExport() {
        let archive = LedgerArchiveService.makeArchive(
            assets: assets,
            transactions: transactions,
            drafts: drafts,
            profile: profiles.first
        )

        do {
            exportText = try LedgerArchiveService.encode(archive)
            statusMessage = "账本备份已生成"
            dataSheet = .exportBackup
        } catch {
            statusMessage = "导出失败，请稍后重试"
        }
    }

    private func importBackup() {
        do {
            let archive = try LedgerArchiveService.decode(importText)
            let summary = LedgerArchiveService.importArchive(
                archive,
                into: modelContext,
                replacingExisting: replacingOnImport,
                existingAssets: assets,
                existingTransactions: transactions,
                existingDrafts: drafts,
                profiles: profiles
            )
            try modelContext.save()
            selectedCurrency = archive.defaultCurrency
            statusMessage = "已导入 \(summary.assetCount) 项资产 / \(summary.transactionCount) 条交易"
            dataSheet = nil
        } catch {
            modelContext.rollback()
            statusMessage = error.localizedDescription
        }
    }

    private func perform(_ confirmation: SettingsConfirmation) {
        switch confirmation {
        case .clearDrafts:
            drafts.forEach(modelContext.delete)
            saveAfterDestructiveAction(successMessage: "草稿队列已清空")
        case .resetLedger:
            drafts.forEach(modelContext.delete)
            transactions.forEach(modelContext.delete)
            assets.forEach(modelContext.delete)
            saveAfterDestructiveAction(successMessage: "本地账本已重置")
        }
    }

    private func saveAfterDestructiveAction(successMessage: String) {
        do {
            try modelContext.save()
            statusMessage = successMessage
        } catch {
            modelContext.rollback()
            statusMessage = "操作失败，请稍后重试"
        }
    }
}

private enum SettingsConfirmation: Identifiable {
    case clearDrafts
    case resetLedger

    var id: String {
        switch self {
        case .clearDrafts:
            return "clear-drafts"
        case .resetLedger:
            return "reset-ledger"
        }
    }

    var title: String {
        switch self {
        case .clearDrafts:
            return "清空草稿队列？"
        case .resetLedger:
            return "重置本地账本？"
        }
    }

    var message: String {
        switch self {
        case .clearDrafts:
            return "待确认草稿会被删除，已入账记录不会受影响。"
        case .resetLedger:
            return "资产、交易记录和待确认草稿都会从本机删除。"
        }
    }

    var actionTitle: String {
        switch self {
        case .clearDrafts:
            return "清空"
        case .resetLedger:
            return "重置"
        }
    }
}

private enum SettingsDataSheet: Identifiable {
    case exportBackup
    case importBackup

    var id: String {
        switch self {
        case .exportBackup:
            return "export-backup"
        case .importBackup:
            return "import-backup"
        }
    }
}

private struct LedgerExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exportText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 18) {
                        TicketPageHeader(title: "导出备份", subtitle: "LEDGER EXPORT", systemImage: "square.and.arrow.up")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "FORMAT", value: "JSON")
                            ReceiptInfoRow(label: "SIZE", value: "\(exportText.count) CHARS")
                            ReceiptInfoRow(label: "STATUS", value: "READY")
                            ReceiptDashedDivider()
                        }

                        Text(exportText)
                            .font(ReceiptStyle.mono(10, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                        ShareLink(item: exportText) {
                            Label("分享备份文本", systemImage: "square.and.arrow.up")
                                .font(ReceiptStyle.mono(13, weight: .bold))
                                .foregroundStyle(ReceiptStyle.paper)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(ReceiptStyle.ink, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("导出备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LedgerImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var importText: String
    @Binding var replacingOnImport: Bool
    let onImport: () -> Void

    private var canImport: Bool {
        !importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ReceiptPaper(tornEdges: false) {
                    VStack(spacing: 18) {
                        TicketPageHeader(title: "导入备份", subtitle: "LEDGER IMPORT", systemImage: "tray.and.arrow.down")

                        VStack(spacing: 7) {
                            ReceiptDashedDivider()
                            ReceiptInfoRow(label: "FORMAT", value: "JSON")
                            ReceiptInfoRow(label: "MODE", value: replacingOnImport ? "REPLACE" : "MERGE")
                            ReceiptInfoRow(label: "STATUS", value: canImport ? "READY" : "PASTE")
                            ReceiptDashedDivider()
                        }

                        Toggle(isOn: $replacingOnImport) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("覆盖当前账本")
                                    .font(ReceiptStyle.mono(13, weight: .bold))
                                Text("关闭后会按 ID 合并同名备份")
                                    .font(ReceiptStyle.mono(11, weight: .semibold))
                                    .foregroundStyle(ReceiptStyle.fadedInk)
                            }
                        }
                        .tint(ReceiptStyle.ink)

                        TextEditor(text: $importText)
                            .font(ReceiptStyle.mono(12, weight: .semibold))
                            .foregroundStyle(ReceiptStyle.ink)
                            .frame(minHeight: 220)
                            .padding(8)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("备份文本")

                        ReceiptActionButton(title: "导入备份", systemImage: "tray.and.arrow.down.fill") {
                            onImport()
                        }
                        .disabled(!canImport)
                        .opacity(canImport ? 1 : 0.45)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(ReceiptStyle.background.ignoresSafeArea())
            .navigationTitle("导入备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}
