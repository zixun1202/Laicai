import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("默认设置") {
                    Text("默认币种：CNY")
                }

                Section("权限") {
                    Text("相册与截图识别")
                    Text("麦克风与语音识别")
                }

                Section("隐私") {
                    Text("数据默认保存在本机")
                    Text("截图与语音在本地处理")
                }
            }
            .navigationTitle("设置")
        }
    }
}
