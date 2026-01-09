//  SegmentedControl .swift
//  Dart Freak
//
//  Created by Billingham Daniel on 2025-11-03.
//

import SwiftUI

struct SegmentedControl<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var titleForOption: (Value) -> String

    init(
        options: [Value],
        selection: Binding<Value>,
        titleForOption: @escaping (Value) -> String = { String(describing: $0) }
    ) {
        self.options = options
        self._selection = selection
        self.titleForOption = titleForOption
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.element) { _, option in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                }) {
                    Text(titleForOption(option))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selection == option ? AppColor.textOnPrimary : AppColor.textOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(selection == option ? AppColor.interactivePrimaryBackground : AppColor.inputBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

private struct SegmentedControlPreviewWrapper: View {
    @State private var selection: Int = 3
    var body: some View {
        SegmentedControl(options: [1, 3, 5, 7], selection: $selection) { value in
            "Best of \(value)"
        }
        .padding()
        .background(AppColor.backgroundPrimary)
    }
}

#Preview {
    SegmentedControlPreviewWrapper()
}
