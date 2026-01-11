
//
//  HomeViewWrapper.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import SwiftUI

/// A wrapper view that safely accesses the modelContext from the environment
/// and uses it to initialize the HomeViewModel and HomeView.
struct HomeViewWrapper: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        // Now that we are inside the view hierarchy, modelContext is available.
        // We can use it to create the viewModel and pass it to the HomeView.
        HomeView(modelContext: modelContext)
    }
}
