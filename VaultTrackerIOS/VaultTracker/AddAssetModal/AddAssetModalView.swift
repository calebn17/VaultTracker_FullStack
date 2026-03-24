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
        VStack {
            Form {
                transactionTypeSection
                accountSection
                assetDetailsSection
                saveButtonSection
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    dismiss()
                }, label: {
                    Label("Close Button", systemImage: "x.circle.fill")
                })
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

    var transactionTypeSection: some View {
        Picker("Transaction Type", selection: $formViewModel.transactionType) {
            ForEach(TransactionType.allCases, id: \.self) { type in
                Text(type.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .listRowInsets(EdgeInsets())
        .accessibilityIdentifier("transactionTypePicker")
    }

    var accountSection: some View {
        Section("Account") {
            TextField(
                formViewModel.selectedCategory != .realEstate ? "Account Name (e.g. Robinhood)" : "Property Address",
                text: $formViewModel.accountName
            )
            .accessibilityIdentifier("accountNameField")

            Picker(
                formViewModel.selectedCategory != .realEstate ? "Account Type" : "Property Type",
                selection: $formViewModel.accountType
            ) {
                ForEach(AccountType.allCases, id: \.self) { type in
                    Text(type.rawValue)
                }
            }
            .accessibilityIdentifier("accountTypePicker")
        }
    }

    var assetDetailsSection: some View {
        Section(header: Text("Asset Details")) {
            Picker("Category", selection: $formViewModel.selectedCategory) {
                ForEach(AssetCategory.allCases, id: \.self) { category in
                    Text(category.rawValue.capitalized)
                }
            }
            .accessibilityIdentifier("categoryPicker")

            TextField(formViewModel.selectedCategory != .realEstate ? "Name" : "Property Name", text: $formViewModel.name)
                .accessibilityIdentifier("assetNameField")

            if formViewModel.shouldShowSymbolField {
                TextField(
                    "Symbol (e.g. BTC, VOO, etc)",
                    text: $formViewModel.symbol
                )
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("symbolField")

                TextField("Quantity", text: formViewModel.quantityBinding)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("quantityField")

                TextField("Price Per Unit", text: $formViewModel.pricePerUnit)
                    .keyboardType(.decimalPad)
                    .accessibilityIdentifier("pricePerUnitField")
            } else {
                TextField(formViewModel.selectedCategory == .cash ? "Amount" : "Equity", text: $formViewModel.pricePerUnit)
                    .accessibilityIdentifier("pricePerUnitField")
            }

            DatePicker("Date", selection: $formViewModel.date)
                .accessibilityIdentifier("transactionDatePicker")
        }
    }

    var saveButtonSection: some View {
        Section {
            CustomButton(label: "Save", labelColor: .white, backgroundColor: formViewModel.isFormValid ? .blue : .gray) {
                Task {
                    if let request = await formViewModel.save() {
                        onSave(request)
                        dismiss()
                    }
                }
            }
            .disabled(!formViewModel.isFormValid)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityIdentifier("saveButton")
        }
    }
}

#Preview {
    NavigationView {
        AddAssetModalView { _ in }
    }
}
