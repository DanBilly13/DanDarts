---
trigger: always_on
---

Task 300: Update Database Schema for Friend Requests
----------------------------------------------------

-   [ ]  Update `friendships` table in Supabase
-   [ ]  Change `status` field to enum: 'pending', 'accepted', 'blocked'
-   [ ]  Add `created_at` timestamp (auto)
-   [ ]  Add `updated_at` timestamp (auto)
-   [ ]  Add `requester_id` field (who sent the request)
-   [ ]  Add `addressee_id` field (who received the request)
-   [ ]  Update RLS policies for pending requests
-   [ ]  Create index on status field
-   [ ]  Test schema with sample data

**Acceptance Criteria:**

-   ✓ Friendship table supports request states
-   ✓ Can distinguish between requester and addressee
-   ✓ RLS policies allow viewing own pending requests
-   ✓ Timestamps track request lifecycle

**Dependencies:** Task 80, Task 81

* * * * *

Task 301: Implement Send Friend Request
---------------------------------------

-   [ ]  Update friend search results UI
-   [ ]  Change "Add Friend" button to "Send Request"
-   [ ]  Create sendFriendRequest(to: User) method in PlayerService
-   [ ]  Insert friendship record with status: 'pending'
-   [ ]  Set requester_id to current user
-   [ ]  Set addressee_id to selected user
-   [ ]  Show success feedback ("Request sent")
-   [ ]  Disable button after sending (show "Request Sent")
-   [ ]  Handle errors (already friends, already pending, blocked)
-   [ ]  Add haptic feedback

**Acceptance Criteria:**

-   ✓ Creates pending friendship record
-   ✓ Prevents duplicate requests
-   ✓ Shows clear visual feedback
-   ✓ Button state updates correctly
-   ✓ Error handling works

**Dependencies:** Task 55, Task 57, Task 300

* * * * *

Task 302: Create Friend Requests View
-------------------------------------

-   [ ]  Create file: Views/Friends/FriendRequestsView.swift
-   [ ]  Add two sections: "Received Requests" and "Sent Requests"
-   [ ]  Display received requests with user cards
-   [ ]  Show "Accept" and "Deny" buttons on each received request
-   [ ]  Display sent requests with user cards
-   [ ]  Show "Withdraw" button on each sent request
-   [ ]  Add empty states for each section
-   [ ]  Show request date ("2 days ago")
-   [ ]  Style per design spec
-   [ ]  Add pull-to-refresh

**Acceptance Criteria:**

-   ✓ Two clear sections visible
-   ✓ All pending requests displayed
-   ✓ Action buttons present and styled
-   ✓ Empty states show when no requests
-   ✓ Dates formatted nicely

**Dependencies:** Task 300

* * * * *

Task 303: Implement Accept Friend Request
-----------------------------------------

-   [ ]  Create acceptFriendRequest(requestId: UUID) method
-   [ ]  Update friendship record status to 'accepted'
-   [ ]  Update both users' friends lists
-   [ ]  Remove from pending requests UI
-   [ ]  Show success feedback ("You are now friends with [Name]")
-   [ ]  Add haptic feedback (success)
-   [ ]  Sync to local friends list
-   [ ]  Handle errors

**Acceptance Criteria:**

-   ✓ Updates status to accepted
-   ✓ Both users see each other as friends
-   ✓ Request removed from pending
-   ✓ Success feedback shown
-   ✓ Error handling works

**Dependencies:** Task 302

* * * * *

Task 304: Implement Deny Friend Request
---------------------------------------

-   [ ]  Create denyFriendRequest(requestId: UUID) method
-   [ ]  Delete friendship record from database
-   [ ]  Remove from received requests UI
-   [ ]  Show subtle feedback ("Request declined")
-   [ ]  Add haptic feedback (light)
-   [ ]  Handle errors
-   [ ]  No notification sent to requester

**Acceptance Criteria:**

-   ✓ Deletes pending request
-   ✓ Removed from UI immediately
-   ✓ No trace left in database
-   ✓ Subtle feedback shown
-   ✓ Error handling works

**Dependencies:** Task 302

* * * * *

Task 305: Implement Withdraw Friend Request
-------------------------------------------

-   [ ]  Create withdrawFriendRequest(requestId: UUID) method
-   [ ]  Delete friendship record from database
-   [ ]  Remove from sent requests UI
-   [ ]  Update search results (re-enable "Send Request" button)
-   [ ]  Show feedback ("Request withdrawn")
-   [ ]  Add haptic feedback (light)
-   [ ]  Handle errors

**Acceptance Criteria:**

-   ✓ Deletes sent request
-   ✓ Removed from UI immediately
-   ✓ Can send new request again
-   ✓ Feedback shown
-   ✓ Error handling works

**Dependencies:** Task 302

* * * * *

Task 306: Implement Block User
------------------------------

-   [ ]  Create blockUser(userId: UUID) method
-   [ ]  If existing friendship: update status to 'blocked'
-   [ ]  If no friendship: create record with status 'blocked'
-   [ ]  Remove user from friends list if currently friends
-   [ ]  Add "Block" option in friend profile view
-   [ ]  Add confirmation alert ("Block [Name]?")
-   [ ]  Block prevents future friend requests
-   [ ]  Show feedback ("User blocked")
-   [ ]  Add haptic feedback (warning)

**Acceptance Criteria:**

-   ✓ Creates/updates block record
-   ✓ Removes from friends if applicable
-   ✓ Prevents future requests both ways
-   ✓ Confirmation prevents accidents
-   ✓ Clear feedback shown

**Dependencies:** Task 59, Task 302

* * * * *

Task 307: Create Block List Management
--------------------------------------

-   [ ]  Add "Blocked Users" section in ProfileView settings
-   [ ]  Create BlockedUsersView
-   [ ]  Display list of blocked users
-   [ ]  Add "Unblock" button for each
-   [ ]  Implement unblockUser(userId: UUID) method
-   [ ]  Delete block record
-   [ ]  Show feedback ("User unblocked")
-   [ ]  Add empty state ("No blocked users")
-   [ ]  Style per design spec

**Acceptance Criteria:**

-   ✓ Shows all blocked users
-   ✓ Unblock functionality works
-   ✓ Updates UI immediately
-   ✓ Empty state when no blocks
-   ✓ Accessible from settings

**Dependencies:** Task 67, Task 306

* * * * *

Task 308: Add Friend Request Badge Indicators
---------------------------------------------

-   [ ]  Add badge count to Friends tab icon
-   [ ]  Count pending received requests
-   [ ]  Update badge when requests received/accepted/denied
-   [ ]  Add red dot indicator on Friends tab
-   [ ]  Add badge to "Requests" button in FriendsListView
-   [ ]  Load pending request count on app launch
-   [ ]  Update count in real-time (if possible) or on tab switch
-   [ ]  Clear badge when all requests viewed
-   [ ]  Style badge per iOS standards

**Acceptance Criteria:**

-   ✓ Badge shows on Friends tab with correct count
-   ✓ Only counts received requests (not sent)
-   ✓ Updates when requests change
-   ✓ Clears when no pending requests
-   ✓ Visible and clear indicator

**Dependencies:** Task 23, Task 302

* * * * *

Task 308.1: Add Navigation to Friend Requests (Bonus)
-----------------------------------------------------

-   [ ]  Add "Requests" button/card in FriendsListView header
-   [ ]  Show badge count on button
-   [ ]  Tap navigates to FriendRequestsView
-   [ ]  Make prominent when requests pending
-   [ ]  Subtle when no requests
-   [ ]  Add SF Symbol icon (bell or person.badge.plus)

**Acceptance Criteria:**

-   ✓ Easy to find in Friends tab
-   ✓ Badge visible
-   ✓ Navigation works
-   ✓ Clear visual hierarchy

**Dependencies:** Task 54, Task 302, Task 308

* * * * *

**Summary:**

-   **Task 300:** Database schema
-   **Task 301:** Send request
-   **Task 302:** Requests UI
-   **Task 303:** Accept request
-   **Task 304:** Deny request
-   **Task 305:** Withdraw request
-   **Task 306:** Block user
-   **Task 307:** Block list management
-   **Task 308:** Badge indicators
-   **Task 308.1:** Navigation to requests