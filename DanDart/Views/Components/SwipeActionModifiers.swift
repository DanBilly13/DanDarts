//
//  SwipeActionModifiers.swift
//  DanDart
//
//  Reusable swipe action modifiers for consistent styling across the app
//

import SwiftUI

// MARK: - View Extension for Swipe Actions

extension View {
    /// Standard delete swipe action with trash icon
    /// - Parameter action: The action to perform when delete is tapped
    /// - Returns: View with swipe action applied
    func deleteSwipeAction(action: @escaping () -> Void) -> some View {
        self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: action) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    /// Custom swipe action with icon and color
    /// - Parameters:
    ///   - title: Action title
    ///   - systemImage: SF Symbol name
    ///   - role: Button role (destructive, cancel, or nil)
    ///   - tint: Background tint color (optional)
    ///   - action: The action to perform
    /// - Returns: View with swipe action applied
    func customSwipeAction(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        self.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: role, action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint ?? AppColor.interactivePrimaryBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(height: 80)
            }
            // Use a consistent background for swipe actions to match card styling
            .tint(AppColor.backgroundPrimary)
        }
    }
    
    /// Multiple swipe actions (e.g., delete and edit)
    /// - Parameter actions: Array of swipe action configurations
    /// - Returns: View with multiple swipe actions applied
    func multipleSwipeActions(@SwipeActionsBuilder actions: () -> [SwipeActionConfig]) -> some View {
        self.modifier(MultipleSwipeActionsModifier(actions: actions()))
    }
}

// MARK: - Swipe Action Configuration

struct SwipeActionConfig: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let tint: Color?
    let action: () -> Void
    
    init(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.tint = tint
        self.action = action
    }
    
    /// Convenience: Delete action
    static func delete(action: @escaping () -> Void) -> SwipeActionConfig {
        SwipeActionConfig(
            title: "Delete",
            systemImage: "trash",
            role: .destructive,
            action: action
        )
    }
    
    /// Convenience: Remove action (less destructive than delete)
    static func remove(action: @escaping () -> Void) -> SwipeActionConfig {
        SwipeActionConfig(
            title: "Remove",
            systemImage: "xmark.circle",
            role: .destructive,
            action: action
        )
    }
    
    /// Convenience: Edit action
    static func edit(action: @escaping () -> Void) -> SwipeActionConfig {
        SwipeActionConfig(
            title: "Edit",
            systemImage: "pencil",
            tint: AppColor.interactivePrimaryBackground,
            action: action
        )
    }
    
    /// Convenience: Block action
    static func block(action: @escaping () -> Void) -> SwipeActionConfig {
        SwipeActionConfig(
            title: "Block",
            systemImage: "hand.raised",
            role: .destructive,
            action: action
        )
    }
}

// MARK: - Result Builder for Swipe Actions

@resultBuilder
struct SwipeActionsBuilder {
    static func buildBlock(_ components: SwipeActionConfig...) -> [SwipeActionConfig] {
        components
    }
}

// MARK: - Multiple Swipe Actions Modifier

struct MultipleSwipeActionsModifier: ViewModifier {
    let actions: [SwipeActionConfig]
    
    func body(content: Content) -> some View {
        content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            ForEach(actions) { config in
                Button(role: config.role, action: config.action) {
                    Image(systemName: config.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(config.tint ?? AppColor.interactivePrimaryBackground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .frame(height: 80)
                }
                // Consistent background tint for all swipe actions
                .tint(AppColor.backgroundPrimary)
            }
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Simple delete action
 PlayerCard(player: player)
     .deleteSwipeAction {
         deletePlayer(player)
     }
 
 // Example 2: Custom action
 PlayerCard(player: player)
     .customSwipeAction(
         title: "Remove",
         systemImage: "xmark.circle",
         role: .destructive
     ) {
         removePlayer(player)
     }
 
 // Example 3: Multiple actions
 PlayerCard(player: player)
     .multipleSwipeActions {
         SwipeActionConfig.edit {
             editPlayer(player)
         }
         SwipeActionConfig.delete {
             deletePlayer(player)
         }
     }
 
 // Example 4: Multiple actions with custom config
 FriendCard(friend: friend)
     .multipleSwipeActions {
         SwipeActionConfig(
             title: "Message",
             systemImage: "message",
             tint: .blue
         ) {
             messageFriend(friend)
         }
         SwipeActionConfig.block {
             blockFriend(friend)
         }
         SwipeActionConfig.delete {
             deleteFriend(friend)
         }
     }
 
 */

#Preview("Swipe Action Demo") {
    List {
        Text("Swipe Me")
            .multipleSwipeActions {
                SwipeActionConfig.edit {
                    print("Edit tapped")
                }
                SwipeActionConfig.delete {
                    print("Delete tapped")
                }
            }
    }
    .background(AppColor.backgroundPrimary)
}
