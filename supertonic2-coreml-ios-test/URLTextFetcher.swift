//
//  URLTextFetcher.swift
//  supertonic2-coreml-ios-test
//
//  Fetches a web page and extracts readable body text suitable for TTS.
//

import Foundation

struct URLTextFetcher {
    enum FetchError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case noReadableContent

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL you entered is not valid."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noReadableContent:
                return "Could not extract readable text from the page."
            }
        }
    }

    /// Fetches and extracts human-readable plain text from the given URL.
    static func fetchText(from url: URL) async throws -> String {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw FetchError.noReadableContent
        }

        let text = extractReadableText(from: html)
        guard !text.isEmpty else {
            throw FetchError.noReadableContent
        }
        return text
    }

    // MARK: - Private HTML parsing

    /// Lightweight HTML-to-text extractor — no dependencies required.
    private static func extractReadableText(from html: String) -> String {
        var text = html

        // Remove <style> blocks.
        text = removeTags(named: "style", from: text)
        // Remove <script> blocks.
        text = removeTags(named: "script", from: text)
        // Remove <nav>, <header>, <footer>, <aside>.
        for tag in ["nav", "header", "footer", "aside", "form"] {
            text = removeTags(named: tag, from: text)
        }

        // Replace common block-level elements with newlines.
        let blockPattern = "</(p|div|h[1-6]|li|br|tr|blockquote|article|section)[^>]*>"
        text = text.replacingOccurrences(
            of: blockPattern,
            with: "\n",
            options: .regularExpression
        )

        // Strip remaining HTML tags.
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode common HTML entities.
        text = decodeHTMLEntities(text)

        // Normalise whitespace.
        text = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        // Collapse runs of blank lines.
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeTags(named tag: String, from html: String) -> String {
        let pattern = "(?i)<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
        return html.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–",
            "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}",
            "&hellip;": "…"
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // Decode hex numeric entities, e.g. &#x00A0;
        result = decodeNumericEntities(result, pattern: "&#x([0-9a-fA-F]+);", hex: true)
        // Decode decimal numeric entities, e.g. &#160;
        result = decodeNumericEntities(result, pattern: "&#([0-9]+);", hex: false)
        return result
    }

    private static func decodeNumericEntities(_ text: String, pattern: String, hex: Bool) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        var result = ""
        var lastEnd = 0
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let fullRange = match.range
            let captureRange = match.range(at: 1)
            // Append text before match.
            result += nsText.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            // Decode the captured number.
            let numStr = nsText.substring(with: captureRange)
            if let codePoint = UInt32(numStr, radix: hex ? 16 : 10),
               let scalar = Unicode.Scalar(codePoint) {
                result += String(scalar)
            }
            lastEnd = fullRange.location + fullRange.length
        }
        result += nsText.substring(from: lastEnd)
        return result
    }
}
