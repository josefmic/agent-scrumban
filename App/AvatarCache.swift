import Foundation

actor AvatarCache {
    static let shared = AvatarCache()

    private var entries: [URL: Data?] = [:]
    private var loads: [URL: Task<Data?, Never>] = [:]

    func data(for url: URL) async -> Data? {
        if let entry = entries[url] { return entry }
        if let load = loads[url] { return await load.value }

        let load = Task<Data?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200
            else { return nil }
            return data
        }
        loads[url] = load

        let result = await load.value
        loads[url] = nil
        entries[url] = result

        return result
    }
}
