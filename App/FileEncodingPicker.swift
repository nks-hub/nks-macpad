import AppKit
import MacPadCore

final class FileEncodingPicker: NSView, NSOpenSavePanelDelegate {
    let selector = NSPopUpButton()
    let preview = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 110))
    var onValidityChanged: ((Bool) -> Void)?
    private(set) var isValid = false
    private var url: URL?
    private var generation = 0
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    var encoding: TextEncoding? {
        get { (selector.selectedItem?.representedObject as? String).flatMap(TextEncoding.init(rawValue:)) }
        set {
            selector.selectItem(at: selector.itemArray.firstIndex { ($0.representedObject as? String) == newValue?.rawValue } ?? 0)
            refreshPreview()
        }
    }

    init(url: URL? = nil, encoding: TextEncoding? = nil) {
        self.url = url
        super.init(frame: NSRect(x: 0, y: 0, width: 480, height: 170))
        let label = NSTextField(labelWithString: L("Kódování:", "Encoding:"))
        label.frame = NSRect(x: 0, y: 145, width: 100, height: 20)
        addSubview(label)
        selector.frame = NSRect(x: 104, y: 140, width: 376, height: 28)
        selector.autoresizingMask = [.width]
        let choices: [(String, TextEncoding?)] = [(L("Automaticky (BOM nebo UTF-8)", "Automatic (BOM or UTF-8)"), nil),
                                                 ("UTF-8", .utf8), ("UTF-16 LE", .utf16LE),
                                                 ("UTF-16 BE", .utf16BE), ("Windows-1250", .windows1250)]
        for (title, value) in choices {
            selector.addItem(withTitle: title)
            selector.lastItem?.representedObject = value?.rawValue
        }
        selector.target = self
        selector.action = #selector(selectionChanged(_:))
        selector.setAccessibilityLabel(L("Kódování při otevření", "Encoding when opening"))
        addSubview(selector)
        let hint = NSTextField(labelWithString: L("Náhled prvního souboru (prvních 800 znaků)", "First file preview (first 800 characters)"))
        hint.frame = NSRect(x: 0, y: 116, width: 480, height: 20)
        hint.autoresizingMask = [.width]
        hint.textColor = .secondaryLabelColor
        addSubview(hint)
        preview.isEditable = false
        preview.isRichText = false
        preview.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        preview.textColor = .textColor
        preview.backgroundColor = .textBackgroundColor
        preview.textContainerInset = NSSize(width: 6, height: 6)
        preview.autoresizingMask = [.width]
        preview.isVerticallyResizable = true
        preview.textContainer?.widthTracksTextView = true
        preview.textContainer?.containerSize = NSSize(width: 480, height: CGFloat.greatestFiniteMagnitude)
        preview.setAccessibilityLabel(L("Náhled dekódovaného textu", "Decoded text preview"))
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 110))
        scroll.autoresizingMask = [.width]
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = preview
        addSubview(scroll)
        self.encoding = encoding
    }

    required init?(coder: NSCoder) { fatalError("Use init(url:encoding:)") }

    func panelSelectionDidChange(_ sender: Any?) {
        url = (sender as? NSOpenPanel)?.urls.first
        refreshPreview()
    }

    @objc private func selectionChanged(_ sender: Any?) { refreshPreview() }

    private func refreshPreview() {
        generation += 1
        let generation = self.generation
        queue.cancelAllOperations()
        isValid = false
        onValidityChanged?(false)
        guard let url else { preview.string = L("Vyberte textový soubor.", "Select a text file."); return }
        preview.string = L("Načítání náhledu…", "Loading preview…")
        let encoding = encoding
        queue.addOperation { [weak self] in
            let result = Result { String(try TextFileStore.read(url, encoding: encoding).text.prefix(800)) }
            // Error alerts run inside the main queue's open callback; a run-loop callback also works in that modal loop.
            RunLoop.main.perform(inModes: [.default, .modalPanel, .eventTracking]) {
                guard let self, self.generation == generation else { return }
                switch result {
                case .success(let text): self.preview.string = text; self.isValid = true
                case .failure(let error): self.preview.string = errorMessage(error)
                }
                self.onValidityChanged?(self.isValid)
            }
        }
    }

    func cancel() { generation += 1; queue.cancelAllOperations() }
}
