//
//  SupabaseService.swift
//  DanDart
//
//  Supabase configuration and client setup
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    // TODO: Replace with actual Supabase credentials from environment variables
    // These are placeholder values - replace with your actual Supabase project credentials
    let supabaseURL = "https://sxovyuctkssdrendihag.supabase.co"
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4b3Z5dWN0a3NzZHJlbmRpaGFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxMTczOTgsImV4cCI6MjA3NTY5MzM5OH0.jDeSDC9dIm2-vLZaOSOSoamEOX8CLNZRweAhZkCC3Rw"
    
    lazy var client: SupabaseClient = {
        // Configure with longer timeout for better reliability
        var config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // 60 seconds
        config.timeoutIntervalForResource = 120 // 120 seconds
        config.waitsForConnectivity = true // Wait for connectivity instead of failing immediately
        
        // Enable detailed logging
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        print("🔧 Supabase Client Configuration:")
        print("   URL: \(supabaseURL)")
        print("   Request Timeout: 60s")
        print("   Resource Timeout: 120s")
        print("   Waits for Connectivity: true")
        
        return SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(),
                auth: SupabaseClientOptions.AuthOptions(
                    flowType: .implicit
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    session: URLSession(configuration: config)
                )
            )
        )
    }()
    
    private init() {
        // Private initializer for singleton pattern
    }
}

// MARK: - Configuration Notes
/*
 To configure Supabase:
 
 1. Create a new Supabase project at https://supabase.com
 2. Get your project URL and anon key from the API settings
 3. Replace the placeholder values above with your actual credentials
 4. Consider using environment variables or a configuration file for production
 
 Environment Variables Setup (recommended):
 - Add SUPABASE_URL and SUPABASE_ANON_KEY to your build configuration
 - Use Bundle.main.object(forInfoDictionaryKey:) to read them
 */
