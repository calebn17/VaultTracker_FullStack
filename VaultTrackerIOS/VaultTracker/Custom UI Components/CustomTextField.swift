//
//  CustomTextField.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/26/25.

import SwiftUI

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    // Optional customization properties
    var cornerRadius: CGFloat = 8
    var borderColor: Color = .gray
    var borderWidth: CGFloat = 1
    var backgroundColor: Color = Color(.systemBackground)
    var textColor: Color = .primary
    var placeholderColor: Color = .secondary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8 ) {
            Text(title)
            
            TextField(placeholder, text: $text)
                .padding()
                .background(backgroundColor)
                .foregroundColor(textColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        
    }
}

#Preview {
    // Default style
    CustomTextField(
        title: "Title",
        placeholder: "Default TextField",
        text: .constant("Sample text")
    )
    
//    // Blue style
//    CustomTextField(
//        placeholder: "Blue styled field",
//        text: .constant(""),
//        cornerRadius: 12,
//        borderColor: .blue,
//        borderWidth: 2,
//        backgroundColor: Color.blue.opacity(0.1)
//    )
//    
//    // Green style with text
//    CustomTextField(
//        placeholder: "Green field",
//        text: .constant("Some content"),
//        borderColor: .green,
//        backgroundColor: Color.green.opacity(0.05)
//    )
}
