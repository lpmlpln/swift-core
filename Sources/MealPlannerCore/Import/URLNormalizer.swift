import Foundation

/// Canonicalizes recipe source URLs so the same page is imported only once.
public enum URLNormalizer {
    /// Returns the canonical import key for a URL, or nil when the URL is not usable.
    public static func normalize(_ raw: String) -> String? {
        guard var components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        guard let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty
        else {
            return nil
        }

        components.scheme = "https"
        components.host = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        components.fragment = nil
        components.user = nil
        components.password = nil

        // Drop tracking parameters and empty values.
        let trackingPrefixes = ["utm_", "fbclid", "gclid", "mc_cid", "mc_eid", "ref", "ref_src"]
        var queryItems = (components.queryItems ?? []).filter { item in
            let name = item.name.lowercased()
            guard !trackingPrefixes.contains(where: { name.hasPrefix($0) }) else { return false }
            return !(item.value ?? "").isEmpty
        }
        queryItems.sort { lhs, rhs in
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return (lhs.value ?? "") < (rhs.value ?? "")
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var path = components.path
        if path.count > 1, path.hasSuffix("/") {
            path = String(path.dropLast())
        }
        components.path = path

        // Default ports are not part of the canonical form.
        if (components.scheme == "https" && components.port == 443)
            || (components.scheme == "http" && components.port == 80) {
            components.port = nil
        }

        return components.string
    }

    public static func isSamePage(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = normalize(lhs), let right = normalize(rhs) else { return false }
        return left == right
    }
}
