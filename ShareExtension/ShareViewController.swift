import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupID = "group.com.nbeyzaei.supertonic2-coreml-ios-test"
    private let pendingTextKey = "shared_pending_text"
    private let urlScheme = "supertonic://speak"

    override func viewDidLoad() {
        super.viewDidLoad()
        extractAndShare()
    }

    private func extractAndShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            completeRequest()
            return
        }

        // Try plain text first
        let textType = UTType.plainText.identifier
        let urlType = UTType.url.identifier

        if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                let text: String
                if let str = item as? String {
                    text = str
                } else if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                    text = str
                } else {
                    self?.completeRequest()
                    return
                }
                self?.saveAndOpen(text: text)
            }
        } else if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                let text: String
                if let url = item as? URL {
                    text = url.absoluteString
                } else if let str = item as? String {
                    text = str
                } else {
                    self?.completeRequest()
                    return
                }
                self?.saveAndOpen(text: text)
            }
        } else {
            completeRequest()
        }
    }

    private func saveAndOpen(text: String) {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(text, forKey: pendingTextKey)
            defaults.synchronize()
        }

        if let url = URL(string: urlScheme) {
            // Use NSXPCConnection-style open to avoid private API
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }

        completeRequest()
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
