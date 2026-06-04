import SwiftUI

// MARK: - 弹出表单
// 新增库存、编辑库存两个 sheet。

struct AddInventorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form = InventoryForm()
    let onAdd: (InventoryForm) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $form.name)
                    HStack {
                        TextField("数量", text: $form.quantity)
                            .keyboardType(.decimalPad)
                        Picker("单位", selection: $form.unit) {
                            ForEach(KitchenData.units, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Picker("分类", selection: $form.category) {
                        ForEach(KitchenData.categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("参考单价 (€/\(form.unit))", text: $form.unitPrice)
                        .keyboardType(.decimalPad)
                }

                Section("高级设置") {
                    TextField("告急阈值", text: $form.threshold)
                        .keyboardType(.decimalPad)

                    Toggle("启用过期日期", isOn: Binding(
                        get: { form.expiryDate != nil },
                        set: { form.expiryDate = $0 ? Date() : nil }
                    ))

                    if form.expiryDate != nil {
                        DatePicker(
                            "过期日期",
                            selection: Binding(
                                get: { form.expiryDate ?? Date() },
                                set: { form.expiryDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }

                    TextField("新鲜天数", text: $form.freshnessDays)
                        .keyboardType(.numberPad)
                }

                Section {
                    Button("添加到库存") {
                        onAdd(form)
                    }
                    .fontWeight(.semibold)
                    .disabled(form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("快速入库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct InventoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: InventoryItem
    let onSave: (InventoryItem) -> Void
    let onDelete: () -> Void

    @State private var quantity: String
    @State private var unitPrice: String
    @State private var threshold: String
    @State private var expiryEnabled: Bool
    @State private var expiryDate: Date
    @State private var freshnessDays: String
    @State private var addedDate: Date

    init(item: InventoryItem, onSave: @escaping (InventoryItem) -> Void, onDelete: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _quantity = State(initialValue: item.quantity)
        _unitPrice = State(initialValue: item.unitPrice?.cleanString ?? "")
        _threshold = State(initialValue: item.threshold?.cleanString ?? "")
        _expiryEnabled = State(initialValue: item.expiryDate != nil)
        _expiryDate = State(initialValue: item.expiryDate.flatMap(DateHelper.date(from:)) ?? Date())
        _freshnessDays = State(initialValue: item.freshnessDays > 0 ? "\(item.freshnessDays)" : "")
        _addedDate = State(initialValue: DateHelper.date(from: item.addedDate) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.name) {
                    HStack {
                        Text("数量 (\(item.unit))")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("参考单价 (€/\(item.unit))")
                        Spacer()
                        TextField("自动估算", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("告急阈值")
                        Spacer()
                        TextField("不提醒", text: $threshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Toggle("启用过期日期", isOn: $expiryEnabled)
                    if expiryEnabled {
                        DatePicker("过期日期", selection: $expiryDate, displayedComponents: .date)
                    }
                    HStack {
                        Text("新鲜天数")
                        Spacer()
                        TextField("不追踪", text: $freshnessDays)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("入库日期", selection: $addedDate, displayedComponents: .date)
                }

                Section {
                    Button("保存") {
                        onSave(
                            InventoryItem(
                                id: item.id,
                                name: item.name,
                                quantity: quantity.isEmpty ? "0" : quantity,
                                unit: item.unit,
                                category: item.category,
                                unitPrice: Double(unitPrice),
                                threshold: Double(threshold),
                                expiryDate: expiryEnabled ? DateHelper.key(for: expiryDate) : nil,
                                freshnessDays: Int(freshnessDays) ?? 0,
                                addedDate: DateHelper.key(for: addedDate),
                                usageSuggestion: item.usageSuggestion
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)

                    Button("删除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("编辑库存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
