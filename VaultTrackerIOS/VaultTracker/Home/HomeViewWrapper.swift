//
//  HomeViewWrapper.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/5/25.
//

import SwiftUI

struct HomeViewWrapper: View {
    var dataRepository: DataRepositoryProtocol?

    var body: some View {
        HomeView(dataRepository: dataRepository)
    }
}
