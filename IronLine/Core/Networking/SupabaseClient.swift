import Foundation
import Supabase

enum SupabaseConfig {
    static let client: SupabaseClient = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
            let urlString = plist["SUPABASE_URL"], let supabaseURL = URL(string: urlString),
            let anonKey = plist["SUPABASE_ANON_KEY"]
        else {
            fatalError("Missing IronLine/Resources/Secrets.plist — copy Secrets.plist.example and fill in your Supabase project credentials.")
        }

        return SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey)
    }()
}
