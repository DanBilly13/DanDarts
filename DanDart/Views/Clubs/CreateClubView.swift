//
//  CreateClubView.swift
//  Dart Freak
//
//  Create a club: a name, an optional town to tell same-named pubs apart, and whether it is
//  Open (found in search, one-tap join) or Invite-only (joined with a link or code). Kept to
//  placeholders and one short line per choice, so the form reads at a glance.
//

import SwiftUI

struct CreateClubView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var clubsService: ClubsService

    @State private var name: String
    @State private var town = ""
    @State private var visibility: ClubVisibility = .open
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var duplicateClubId: UUID?

    /// Same limits the database enforces.
    static let maxNameLength = 40
    static let maxTownLength = 40

    init(initialName: String = "") {
        _name = State(initialValue: Self.clamped(initialName, to: Self.maxNameLength))
    }

    /// The database counts code points, not characters, so an emoji-heavy name is cut the same way.
    static func clamped(_ text: String, to limit: Int) -> String {
        guard text.unicodeScalars.count > limit else { return text }
        return String(String.UnicodeScalarView(text.unicodeScalars.prefix(limit)))
    }

    /// The database wants at least 3 letters or numbers in the name.
    static func isValidName(_ text: String) -> Bool {
        text.filter { $0.isLetter || $0.isNumber }.count >= 3
    }

    private var canCreate: Bool {
        Self.isValidName(name) && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // The titles are the VoiceOver labels; sighted people read the placeholders.
                    TextField("Club name", text: $name, prompt: Text("Club name").foregroundColor(AppColor.textSecondary))
                        .textFieldStyle(DartTextFieldStyle())
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)

                    TextField("Town", text: $town, prompt: Text("Town (optional)").foregroundColor(AppColor.textSecondary))
                        .textFieldStyle(DartTextFieldStyle())
                        .textInputAutocapitalization(.words)

                    visibilityChoice
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            AppButton(role: .primary, controlSize: .large, isDisabled: !canCreate, action: create) {
                if isCreating {
                    ProgressView().tint(AppColor.justWhite)
                } else {
                    Text("Create club")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AppColor.backgroundPrimary)
        .navigationTitle("Create a club")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: name) { _, newValue in
            let clamped = Self.clamped(newValue, to: Self.maxNameLength)
            if clamped != newValue { name = clamped }
        }
        .onChange(of: town) { _, newValue in
            let clamped = Self.clamped(newValue, to: Self.maxTownLength)
            if clamped != newValue { town = clamped }
        }
        .alert("Couldn't create the club", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("That club already exists", isPresented: Binding(
            get: { duplicateClubId != nil },
            set: { if !$0 { duplicateClubId = nil } }
        )) {
            Button("Join it") { joinExisting() }
            Button("Cancel", role: .cancel) { duplicateClubId = nil }
        } message: {
            Text("There's already an Open club with that name and town. Do you want to join it instead?")
        }
    }

    // MARK: - Open / Invite-only

    private var visibilityChoice: some View {
        VStack(alignment: .leading, spacing: 12) {
            visibilityCard(.open, title: "Open", detail: "Anyone can find it and join")
            visibilityCard(.invite, title: "Invite-only", detail: "Hidden. People join with a link or code")
        }
    }

    private func visibilityCard(_ option: ClubVisibility, title: String, detail: String) -> some View {
        let selected = visibility == option
        return Button {
            visibility = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? AppColor.interactivePrimaryBackground : AppColor.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(selected ? AppColor.interactivePrimaryBackground : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Actions

    private func create() {
        guard canCreate else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let outcome = try await clubsService.createClub(name: name, town: town, visibility: visibility)
                switch outcome.result {
                case .ok:
                    router.popToRoot() // back to the Clubs tab, even when we came through Find
                case .duplicate:
                    if let existing = outcome.clubId {
                        duplicateClubId = existing
                    } else {
                        errorMessage = outcome.result.userMessage
                    }
                default:
                    errorMessage = outcome.result.userMessage ?? "Please try again."
                }
            } catch {
                print("❌ [Clubs] Create failed: \(error)")
                errorMessage = "Check your connection and try again."
            }
        }
    }

    private func joinExisting() {
        guard let id = duplicateClubId else { return }
        duplicateClubId = nil
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let outcome = try await clubsService.joinClub(clubId: id)
                switch outcome.result {
                case .ok, .alreadyMember:
                    router.popToRoot()
                default:
                    errorMessage = outcome.result.userMessage ?? "Please try again."
                }
            } catch {
                print("❌ [Clubs] Join existing failed: \(error)")
                errorMessage = "Check your connection and try again."
            }
        }
    }
}
