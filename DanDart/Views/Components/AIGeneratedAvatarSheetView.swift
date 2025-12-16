import SwiftUI

#if canImport(PhotosUI)
import PhotosUI
#else
struct PhotosPickerItem { }
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

struct AIGeneratedAvatarSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedAvatar: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedAvatarImage: UIImage?

    @StateObject private var viewModel: AvatarGenerationViewModel

    init(
        selectedAvatar: Binding<String>,
        selectedPhotoItem: Binding<PhotosPickerItem?>,
        selectedAvatarImage: Binding<UIImage?>,
        service: AvatarGenerationService = MockAvatarGenerationService()
    ) {
        self._selectedAvatar = selectedAvatar
        self._selectedPhotoItem = selectedPhotoItem
        self._selectedAvatarImage = selectedAvatarImage
        self._viewModel = StateObject(wrappedValue: AvatarGenerationViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if case let .error(message) = viewModel.state {
                    VStack(spacing: 12) {
                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            regenerate()
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColor.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColor.inputBackground)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if viewModel.state == .generating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColor.interactivePrimaryBackground))
                            .scaleEffect(1.1)

                        Text("Generating avatar…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(.top, 24)

                    Spacer()
                } else if let generatedImage = viewModel.previewImage {
                    VStack(spacing: 16) {
                        Image(uiImage: generatedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.top, 16)

                        HStack(spacing: 12) {
                            Button(action: {
                                regenerate()
                            }) {
                                Text("Regenerate")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColor.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AppColor.inputBackground)
                                    .cornerRadius(12)
                            }

                            Button(action: {
                                useGeneratedAvatar()
                            }) {
                                Text("Use This Avatar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColor.textOnPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AppColor.interactivePrimaryBackground)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a style")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(AvatarGenerationStyle.allCases) { style in
                                Button(action: {
                                    selectStyle(style)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: style.iconSystemName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColor.interactivePrimaryBackground)

                                        Text(style.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColor.textPrimary)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColor.textSecondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 52)
                                    .background(AppColor.inputBackground)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        Text("(Uses Apple Intelligence)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.top, 4)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Generate Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                }
            }
            .onDisappear {
                viewModel.cancelInFlight()
            }
            .task(id: viewModel.state) {
                if case .error = viewModel.state {
                    triggerWarningHaptic()
                }
            }
        }
    }

    private func selectStyle(_ style: AvatarGenerationStyle) {
        triggerLightHaptic()
        viewModel.selectStyle(style)
    }

    private func regenerate() {
        triggerLightHaptic()
        viewModel.regenerate()
    }

    private func useGeneratedAvatar() {
        guard let generatedImage = viewModel.previewImage else { return }

        triggerMediumHaptic()

        #if canImport(UIKit)
        selectedAvatarImage = generatedImage.resized(toMaxDimension: 512)
        #else
        selectedAvatarImage = generatedImage
        #endif
        selectedPhotoItem = nil
        selectedAvatar = ""

        dismiss()
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func triggerMediumHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    private func triggerWarningHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
