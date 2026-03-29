//
//  AddAssetModalView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/29/25.
//

import SwiftUI

struct AddAssetModalView: View {

    @StateObject private var formViewModel: AddAssetFormViewModel
    @Environment(\.dismiss) private var dismiss
    private var onSave: (APISmartTransactionCreateRequest) -> Void

    init(onSave: @escaping (APISmartTransactionCreateRequest) -> Void) {
        self.onSave = onSave
        _formViewModel = StateObject(wrappedValue: AddAssetFormViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Transaction Type", selection: $formViewModel.transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("transactionTypePicker")
                    .listRowBackground(VTColors.surface)
                }

                Section {
                    TextField(
                        formViewModel.selectedCategory != .realEstate ? "Account Name (e.g. Robinhood)" : "Property Address",
                        text: $formViewModel.accountName
                    )
                    .foregroundStyle(VTColors.textPrimary)
                    .accessibilityIdentifier("accountNameField")
                    .listRowBackground(VTColors.surface)

                    Picker(
                        formViewModel.selectedCategory != .realEstate ? "Account Type" : "Property Type",
                        selection: $formViewModel.accountType
                    ) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Text(type.rawValue)
                        }
                    }
                    .accessibilityIdentifier("accountTypePicker")
                    .listRowBackground(VTColors.surface)
                } header: {
                    Text("Account")
                        .font(VTFonts.sectionHeader)
                        .foregroundStyle(VTColors.textSubdued)
                        .textCase(.uppercase)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AssetCategory.allCases, id: \.self) { category in
                                Button {
                                    formViewModel.selectedCategory = category
                                } label: {
                                    Text(category.rawValue.capitalized)
                                }
                                .buttonStyle(FilterChipStyle(isSelected: formViewModel.selectedCategory == category))
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("categoryPicker")
                        .accessibilityAddTraits(.isButton)
                    }
                    .listRowBackground(VTColors.surface)

                    TextField(formViewModel.selectedCategory != .realEstate ? "Name" : "Property Name", text: $formViewModel.name)
                        .foregroundStyle(VTColors.textPrimary)
                        .accessibilityIdentifier("assetNameField")
                        .listRowBackground(VTColors.surface)

                    if formViewModel.shouldShowSymbolField {
                        TextField(
                            "Symbol (e.g. BTC, VOO, etc)",
                            text: $formViewModel.symbol
                        )
                        .textInputAutocapitalization(.characters)
                        .foregroundStyle(VTColors.textPrimary)
                        .accessibilityIdentifier("symbolField")
                        .listRowBackground(VTColors.surface)

                        TextField("Quantity", text: formViewModel.quantityBinding)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(VTColors.textPrimary)
                            .accessibilityIdentifier("quantityField")
                            .listRowBackground(VTColors.surface)

                        TextField("Price Per Unit", text: $formViewModel.pricePerUnit)
                            .keyboardType(.decimalPad)
                            .foregroundStyle(VTColors.textPrimary)
                            .accessibilityIdentifier("pricePerUnitField")
                            .listRowBackground(VTColors.surface)
                    } else {
                        TextField(formViewModel.selectedCategory == .cash ? "Amount" : "Equity", text: $formViewModel.pricePerUnit)
                            .foregroundStyle(VTColors.textPrimary)
                            .accessibilityIdentifier("pricePerUnitField")
                            .listRowBackground(VTColors.surface)
                    }

                    DatePicker("Date", selection: $formViewModel.date)
                        .tint(VTColors.primary)
                        .accessibilityIdentifier("transactionDatePicker")
                        .listRowBackground(VTColors.surface)
                } header: {
                    Text("Asset Details")
                        .font(VTFonts.sectionHeader)
                        .foregroundStyle(VTColors.textSubdued)
                        .textCase(.uppercase)
                }

                Section {
                    Button {
                        Task {
                            if let request = await formViewModel.save() {
                                onSave(request)
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(VTPrimaryButtonStyle(isEnabled: formViewModel.isFormValid))
                    .disabled(!formViewModel.isFormValid)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(VTColors.background)
                    .accessibilityIdentifier("saveButton")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(VTColors.background)
        .presentationBackground(VTColors.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "x.circle.fill")
                        .foregroundStyle(VTColors.textSubdued)
                }
                .accessibilityIdentifier("closeButton")
            }
        }
        .alert("Error", isPresented: $formViewModel.shouldShowAlert) {
            Button("OK") {
                formViewModel.shouldShowAlert = false
            }
        } message: {
            Text(formViewModel.alertMessage)
        }
    }
}

#Preview {
    NavigationView {
        AddAssetModalView { _ in }
    }
}
