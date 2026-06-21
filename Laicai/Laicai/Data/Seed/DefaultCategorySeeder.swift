import Foundation
import SwiftData

enum DefaultCategorySeeder {
    static func defaultCategories() -> [AssetCategory] {
        [
            AssetCategory(
                name: "现金与账户",
                iconName: "wallet.pass",
                colorHex: "#B6B0AA",
                sortOrder: 0,
                subtypes: ["现金", "银行卡", "信用卡余额", "微信余额", "支付宝余额"]
            ),
            AssetCategory(
                name: "投资资产",
                iconName: "chart.line.uptrend.xyaxis",
                colorHex: "#D0B56E",
                sortOrder: 1,
                subtypes: ["股票", "基金", "理财产品", "债券", "黄金", "加密资产"]
            ),
            AssetCategory(
                name: "固定资产",
                iconName: "building.2",
                colorHex: "#8EB697",
                sortOrder: 2,
                subtypes: ["房产", "车辆"]
            ),
            AssetCategory(
                name: "负债",
                iconName: "creditcard.and.123",
                colorHex: "#C48E8E",
                sortOrder: 3,
                subtypes: ["房贷", "车贷", "消费贷", "信用卡应还"]
            )
        ]
    }

    static func seedIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<AssetCategory>()
        let existing = try context.fetch(descriptor)
        guard existing.isEmpty else { return }
        defaultCategories().forEach { context.insert($0) }
        try context.save()
    }
}
