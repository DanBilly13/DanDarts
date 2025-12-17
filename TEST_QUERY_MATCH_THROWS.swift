// Test query for match_throws_test table
// Add this temporarily to MatchesService.swift to test

// TEST FUNCTION - Add to MatchesService class
func testQueryMatchThrowsTest() async {
    print("🧪 Testing query on match_throws_test table...")
    
    do {
        let result = try await supabaseService.client
            .from("match_throws_test")
            .select("id,match_id,player_order,turn_index,throws,score_before,score_after,game_metadata")
            .execute()
        
        print("✅ Test query succeeded!")
        print("📊 Response data: \(String(data: result.data, encoding: .utf8) ?? "nil")")
        
        // Try to parse the response
        if let throwsArray = try? JSONSerialization.jsonObject(with: result.data) as? [[String: Any]] {
            print("✅ Successfully parsed \(throwsArray.count) rows")
            for (index, row) in throwsArray.enumerated() {
                print("   Row \(index): throws = \(row["throws"] ?? "nil")")
            }
        } else {
            print("⚠️ Failed to parse response as JSON array")
        }
        
    } catch {
        print("❌ Test query failed: \(error)")
    }
}

// Call this from somewhere in your app to test, e.g., in MatchHistoryView.onAppear:
// Task {
//     await MatchesService.shared.testQueryMatchThrowsTest()
// }
