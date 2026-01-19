//
//  TermsAndPrivacyText.swift
//  DanDart
//
//  Reusable Terms & Privacy acceptance text component
//

import SwiftUI

struct TermsAndPrivacyText: View {
    @Binding var showTerms: Bool
    @Binding var showPrivacy: Bool
    
    var body: some View {
        Text(termsAndPrivacyAttributedString)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .tint(AppColor.justWhite)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 32)
            .environment(\.openURL, OpenURLAction { url in
                // Handle our internal link taps by opening sheets
                if url.scheme == "dartfreak" {
                    switch url.host {
                    case "terms":
                        showTerms = true
                        return .handled
                    case "privacy":
                        showPrivacy = true
                        return .handled
                    default:
                        return .discarded
                    }
                }
                return .systemAction
            })
    }
    
    private var termsAndPrivacyAttributedString: AttributedString {
        var text = AttributedString("By continuing, you agree to the\nTerms & Conditions and Privacy Policy.")
        
        if let termsRange = text.range(of: "Terms & Conditions") {
            text[termsRange].link = URL(string: "dartfreak://terms")
        }
        
        if let privacyRange = text.range(of: "Privacy Policy") {
            text[privacyRange].link = URL(string: "dartfreak://privacy")
        }
        
        return text
    }
}
