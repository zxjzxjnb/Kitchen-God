import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KitchenStore.self) private var store

    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("灶王爷设置"), footer: Text("兼容 OpenAI 格式接口。请妥善保管 API Key。")) {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Base URL (如: https://api.openai.com/v1)", text: $baseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)

                    TextField("Model (如: gpt-4o-mini, deepseek-chat)", text: $model)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.aiApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.aiBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.aiModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.showToast("设置已保存")
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = store.aiApiKey
                baseURL = store.aiBaseURL
                model = store.aiModel
            }
        }
    }
}
