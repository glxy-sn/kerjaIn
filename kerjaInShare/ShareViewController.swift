import AppKit
import SwiftUI

@objc(ShareViewController)
class ShareViewController: NSViewController {
    override func loadView() {
        guard let context = extensionContext else {
            view = NSView(); return
        }
        let shareView = ShareView(extensionContext: context)
        let host = NSHostingView(rootView: shareView)
        host.frame = CGRect(x: 0, y: 0, width: 520, height: 420)
        view = host
        preferredContentSize = CGSize(width: 520, height: 420)
    }
}
