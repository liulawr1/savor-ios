import Foundation

struct APIService {
    private var baseURL: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), let url = ProcessInfo.processInfo.environment["SAVOR_TEST_SERVER_URL"] { return url }
        return Bundle.main.object(forInfoDictionaryKey: "SavorServerURL") as? String ?? ""
        #else
        return ""
        #endif
    }
    private var token: String {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), let token = ProcessInfo.processInfo.environment["SAVOR_TEST_CLIENT_TOKEN"] { return token }
        return Bundle.main.object(forInfoDictionaryKey: "SavorClientToken") as? String ?? ""
        #else
        return ""
        #endif
    }
    var configured: Bool { !baseURL.isEmpty && token.count >= 32 }
    private func send(path: String, body: Data? = nil) async throws -> Data {
        guard configured, let url = URL(string: baseURL), let host = url.host else { throw SavorError.message("Live AI isn’t connected in this build. You can still manage your pantry or explore the sample kitchen.") }
        var allowed = url.scheme == "https"
        #if DEBUG
        allowed = allowed || (url.scheme == "http" && (host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".local")))
        #endif
        guard allowed else { throw SavorError.message("The kitchen connection needs a secure server address.") }
        var request = URLRequest(url: url.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body; request.timeoutInterval = 55
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SavorError.message("The kitchen couldn’t be reached. Try again in a moment.") }
            guard (200..<300).contains(http.statusCode) else {
                struct Failure: Decodable { let error: String }
                throw SavorError.message((try? JSONDecoder().decode(Failure.self, from: data).error) ?? "We couldn’t finish that request. Please try again.")
            }
            return data
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw SavorError.message(error.code == .timedOut ? "That took longer than expected. Please try again." : "The kitchen is offline. Keep your ingredients here and try again when the connection is back.")
        }
    }
    func health() async throws -> Bool {
        struct Health: Decodable { let aiConfigured: Bool }
        return try JSONDecoder().decode(Health.self, from: await send(path: "health")).aiConfigured
    }
    func scan(_ photo: Data) async throws -> ScanResult {
        let body = try JSONSerialization.data(withJSONObject: ["imageBase64": photo.base64EncodedString()])
        return try JSONDecoder().decode(ScanResult.self, from: await send(path: "v1/scan", body: body))
    }
    func meals(items: [PantryItem], minutes: Int, servings: Int, style: String, allowShopping: Bool, equipment: [String]) async throws -> [Recipe] {
        let input: [String: Any] = ["items": items.map { ["id": $0.id, "name": $0.name, "quantity": $0.quantity, "category": $0.category, "useSoon": $0.useSoon] as [String: Any] }, "minutes": minutes, "servings": servings, "style": style, "allowShopping": allowShopping, "equipment": equipment]
        struct Result: Decodable { let recipes: [Recipe] }
        return try JSONDecoder().decode(Result.self, from: await send(path: "v1/meals", body: JSONSerialization.data(withJSONObject: input))).recipes
    }
    func adjust(recipe: Recipe, items: [PantryItem], preferences: CookingPreferences, request: String, excludedIDs: Set<String>, equipment: [String]) async throws -> Recipe {
        struct Input: Encodable {
            let original: Recipe
            let items: [PantryItem]
            let minutes: Int
            let servings: Int
            let style: String
            let allowShopping: Bool
            let adjustment: String
            let excludedIDs: [String]
            let equipment: [String]
        }
        struct Result: Decodable { let recipe: Recipe }
        let input = Input(original: recipe, items: items, minutes: preferences.minutes, servings: preferences.servings, style: preferences.style, allowShopping: preferences.allowShopping, adjustment: request, excludedIDs: excludedIDs.sorted(), equipment: equipment)
        return try JSONDecoder().decode(Result.self, from: await send(path: "v1/adjust", body: JSONEncoder().encode(input))).recipe
    }

}
