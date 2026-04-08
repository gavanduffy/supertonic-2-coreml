//
//  URLTextFetcher.swift
//  supertonic2-coreml-ios-test
//
//  Fetches a web page and extracts readable body text suitable for TTS.
//  Strategy:
//    1. Cache check — SHA-256 keyed, 24-hour TTL, stored in Caches directory.
//    2. Fast path — URLSession GET + lightweight HTML/PDF strip.
//    3. Fallback — WKWebView (renders JS) + injected extraction script when the
//       fast path produces fewer than 200 meaningful characters.
//

import Foundation
import WebKit
import PDFKit
import CryptoKit

// MARK: - Public interface

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

    // MARK: - Cache (B3)

    private static let cacheTTL: TimeInterval = 86_400  // 24 hours

    private static var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("url_text_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func cachedText(for url: URL) -> String? {
        let file = cacheDirectory.appendingPathComponent(cacheKey(for: url) + ".txt")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < cacheTTL,
              let text = try? String(contentsOf: file, encoding: .utf8),
              !text.isEmpty else { return nil }
        return text
    }

    private static func cache(text: String, for url: URL) {
        let file = cacheDirectory.appendingPathComponent(cacheKey(for: url) + ".txt")
        try? text.write(to: file, atomically: true, encoding: .utf8)
    }

    // MARK: - Public entry

    /// Fetches and extracts human-readable plain text from the given URL.
    /// Checks a 24-hour SHA-256-keyed cache first; uses a WKWebView fallback for JS-heavy pages.
    static func fetchText(from url: URL) async throws -> String {
        // --- Cache check ---
        if let cached = cachedText(for: url) {
            return cached
        }

        // --- Fast path: plain URLSession GET + HTML/PDF strip ---
        let fastResult = try? await fetchFast(from: url)
        if let text = fastResult, text.count >= 200 {
            cache(text: text, for: url)
            return text
        }

        // --- Slow path: render with WKWebView ---
        do {
            let webText = try await WebViewExtractor.extract(from: url)
            if webText.count >= 50 {
                cache(text: webText, for: url)
                return webText
            }
        } catch {
            // If WKWebView also fails, surface the fast path result (or throw)
            if let text = fastResult, !text.isEmpty {
                cache(text: text, for: url)
                return text
            }
            throw FetchError.noReadableContent
        }

        if let text = fastResult, !text.isEmpty {
            cache(text: text, for: url)
            return text
        }
        throw FetchError.noReadableContent
    }

    // MARK: - Fast path

    private static func fetchFast(from url: URL) async throws -> String {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FetchError.networkError(error)
        }

        // B1: PDF detection — check Content-Type header
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.lowercased().contains("application/pdf") {
            return extractPDFText(from: data)
        }

        // Also check URL extension as a fallback hint
        if url.pathExtension.lowercased() == "pdf" {
            let pdfText = extractPDFText(from: data)
            if !pdfText.isEmpty { return pdfText }
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

    // MARK: - PDF extractor (B1)

    /// Extracts plain text from raw PDF data using PDFKit, page by page.
    private static func extractPDFText(from data: Data) -> String {
        guard let document = PDFDocument(data: data) else { return "" }
        var pages: [String] = []
        for i in 0 ..< document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string,
               !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pages.append(pageText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return pages.joined(separator: "\n\n")
    }

    // MARK: - Lightweight HTML-to-text extractor

    /// Lightweight HTML-to-text extractor — no dependencies required.
    static func extractReadableText(from html: String) -> String {
        var text = html

        // Remove <style> blocks.
        text = removeTags(named: "style", from: text)
        // Remove <script> blocks.
        text = removeTags(named: "script", from: text)
        // Remove <nav>, <header>, <footer>, <aside>, <form>.
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
            result += nsText.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
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

// MARK: - WKWebView-based extractor

/// Renders the page in a headless WKWebView, then injects a JS extraction
/// script to pull the article body text. Works for SPAs and JS-rendered pages.
@MainActor
private final class WebViewExtractor: NSObject, WKNavigationDelegate {

    private let webView: WKWebView
    private var continuation: CheckedContinuation<String, Error>?
    private var hasFinished = false

    // JS that walks the DOM and extracts readable text, mimicking Readability heuristics.
    private static let extractionScript = """
    (function() {
        // Remove boilerplate containers.
        var boilerplate = ['nav','header','footer','aside','form',
                           '[role="navigation"]','[role="banner"]','[role="contentinfo"]',
                           '.cookie-banner','.ad','.ads','.advertisement'];
        boilerplate.forEach(function(sel) {
            try {
                document.querySelectorAll(sel).forEach(function(el){ el.remove(); });
            } catch(e){}
        });
        // Prefer <article>, <main>, or the element with the most text.
        var candidates = ['article','[role="main"]','main','.post-content',
                          '.article-body','.entry-content','.content','#content','body'];
        var best = null;
        for (var i = 0; i < candidates.length; i++) {
            var el = document.querySelector(candidates[i]);
            if (el && el.innerText && el.innerText.trim().length > 100) {
                best = el;
                break;
            }
        }
        if (!best) best = document.body;
        if (!best) return '';
        // Collect text, preserving paragraph breaks.
        var blocks = best.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,blockquote');
        if (blocks.length > 3) {
            return Array.from(blocks)
                .map(function(b){ return b.innerText.trim(); })
                .filter(function(t){ return t.length > 0; })
                .join('\\n');
        }
        return best.innerText || '';
    })();
    """

    private init(url: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    static func extract(from url: URL, timeout: TimeInterval = 15) async throws -> String {
        let extractor = WebViewExtractor(url: url)
        return try await withTimeout(seconds: timeout) {
            try await extractor.run(url: url)
        }
    }

    private func run(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = URLRequest(url: url, timeoutInterval: 12)
            webView.load(request)
        }
    }

    // MARK: WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard !self.hasFinished else { return }
            // Give JS a brief moment to run after didFinish.
            try? await Task.sleep(nanoseconds: 800_000_000)
            self.extractAndFinish()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(with: .failure(URLTextFetcher.FetchError.networkError(error)))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.finish(with: .failure(URLTextFetcher.FetchError.networkError(error)))
        }
    }

    private func extractAndFinish() {
        webView.evaluateJavaScript(Self.extractionScript) { [weak self] result, error in
            guard let self = self else { return }
            if let text = result as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = URLTextFetcher.extractReadableText(from: text)
                self.finish(with: .success(cleaned.isEmpty ? text : cleaned))
            } else {
                self.finish(with: .failure(URLTextFetcher.FetchError.noReadableContent))
            }
        }
    }

    private func finish(with result: Result<String, Error>) {
        guard !hasFinished else { return }
        hasFinished = true
        continuation?.resume(with: result)
        continuation = nil
    }
}

// MARK: - Timeout helper

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw URLTextFetcher.FetchError.noReadableContent
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
