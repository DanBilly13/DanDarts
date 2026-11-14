//
//  AgeAndTermsCheckbox.swift
//  Dart Freak
//
//  The "I'm 13 or over and agree to the Terms and Privacy Policy" tick-box shown where an
//  account can be created. Nothing is stored: it only unlocks the sign-up buttons.
//

import SwiftUI

/// The one rule behind the tick-box, kept apart from the screens so it can be tested.
enum SignUpGate {
    /// Accounts can only be created once the box is ticked and the form (if there is one) is valid.
    static func allowsSignUp(hasAgreed: Bool, formIsValid: Bool = true) -> Bool {
        hasAgreed && formIsValid
    }
}

struct AgeAndTermsCheckbox: View {
    @Binding var isChecked: Bool
    @Binding var showTerms: Bool
    @Binding var showPrivacy: Bool

    private static let label = "I'm 13 or over and agree to the Terms & Conditions and Privacy Policy"

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                isChecked.toggle()
            } label: {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(isChecked ? AppColor.interactivePrimaryBackground : AppColor.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.label)
            .accessibilityValue(isChecked ? "Ticked" : "Not ticked")
            .accessibilityAddTraits(.isButton)

            Text(attributedLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(AppColor.justWhite)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.openURL, OpenURLAction { url in
                    guard url.scheme == "dartfreak" else { return .systemAction }
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
                })
        }
        .padding(.horizontal, 24)
    }

    private var attributedLabel: AttributedString {
        var text = AttributedString(Self.label)
        if let range = text.range(of: "Terms & Conditions") {
            text[range].link = URL(string: "dartfreak://terms")
        }
        if let range = text.range(of: "Privacy Policy") {
            text[range].link = URL(string: "dartfreak://privacy")
        }
        return text
    }
}
