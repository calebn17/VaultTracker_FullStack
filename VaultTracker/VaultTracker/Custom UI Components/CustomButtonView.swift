//
//  CustomButtonView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/26/25.
//

import SwiftUI

struct CustomButton: View {
    
    let label: String
    let labelColor: Color
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }, label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(backgroundColor)
                Text(label)
                    .foregroundStyle(labelColor)
            }
        })
    }
}

#Preview {
    Group {
        CustomButton(label: "Text example", labelColor: .white, backgroundColor: .cyan) {
            return
        }
    }
}
