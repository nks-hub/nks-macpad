import AppKit

enum MarkdownRenderer {
    static func allowedLink(_ value: Any) -> URL? {
        let url = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
        guard let url, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func render(_ source: String, fontSize: CGFloat) throws -> NSAttributedString {
        let parsed = try AttributedString(markdown: source, options: .init(interpretedSyntax: .full))
        let output = NSMutableAttributedString()
        var previousBlock: Int?
        var previousList: Int?
        var seenItems = Set<Int>()
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let block = components.first?.identity
            var heading: Int?
            var listItem: (id: Int, ordinal: Int)?
            var listID: Int?
            var ordered = false
            var depth = 0
            var codeBlock = false
            var quote = false
            for component in components {
                switch component.kind {
                case .header(let level): heading = level
                case .listItem(let ordinal):
                    if listItem == nil { listItem = (component.identity, ordinal) }
                case .orderedList, .unorderedList:
                    depth += 1
                    if listID == nil {
                        listID = component.identity
                        if case .orderedList = component.kind { ordered = true }
                    }
                case .codeBlock: codeBlock = true
                case .blockQuote: quote = true
                default: break
                }
            }
            var text = String(parsed[run.range].characters)
            if block != previousBlock || (block == nil && output.length > 0) {
                if output.length > 0 {
                    output.append(NSAttributedString(string: listID != nil && listID == previousList ? "\n" : "\n\n"))
                }
                var prefix = quote ? "│ " : ""
                if let item = listItem, seenItems.insert(item.id).inserted {
                    prefix += String(repeating: "    ", count: max(0, depth - 1))
                    if text.hasPrefix("[ ] ") { prefix += "☐ "; text.removeFirst(4) }
                    else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") { prefix += "☑ "; text.removeFirst(4) }
                    else { prefix += ordered ? "\(item.ordinal). " : "• " }
                }
                text = prefix + text
            }
            previousBlock = block
            previousList = listID
            let inline = run.inlinePresentationIntent ?? []
            let size = heading.map { fontSize * (1.9 - CGFloat($0 - 1) * 0.15) } ?? fontSize
            let base = codeBlock || inline.contains(.code) ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
                                                          : NSFont.systemFont(ofSize: size)
            var traits = base.fontDescriptor.symbolicTraits
            if heading != nil || inline.contains(.stronglyEmphasized) { traits.insert(.bold) }
            if inline.contains(.emphasized) { traits.insert(.italic) }
            let font = NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits), size: size) ?? base
            var attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor]
            if codeBlock || inline.contains(.code) { attributes[.backgroundColor] = NSColor.controlBackgroundColor }
            if inline.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = run.link.flatMap({ allowedLink($0) }) {
                attributes[.link] = link
                attributes[.foregroundColor] = NSColor.linkColor
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            // Image URLs and all other parser attributes are deliberately not copied into NSTextView.
            if run.imageURL != nil { text = "[" + L("Obrázek: ", "Image: ") + text + "]" }
            output.append(NSAttributedString(string: text, attributes: attributes))
        }
        return output
    }
}

final class MarkdownPreview: NSView, NSTextViewDelegate {
    weak var owner: EditorWindowController?
    let textView = MarkdownTextView()
    private let label = NSTextField(labelWithString: L("Náhled Markdownu", "Markdown preview"))
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var pending: DispatchWorkItem?
    private var generation = 0
    private(set) var renderedRevision: UInt64?
    private(set) var renderedNoteID: UUID?

    init(owner: EditorWindowController) {
        self.owner = owner
        super.init(frame: .zero)
        textView.preview = self
        textView.delegate = self
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude)
        textView.backgroundColor = .textBackgroundColor
        textView.setAccessibilityLabel(L("Náhled Markdownu pouze ke čtení", "Read-only Markdown preview"))
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = textView
        let close = NSButton(title: L("Zavřít náhled", "Close preview"), target: self, action: #selector(closePreview(_:)))
        close.bezelStyle = .rounded
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        close.setContentCompressionResistancePriority(.required, for: .horizontal)
        let header = NSStackView(views: [label, NSView(), close])
        header.spacing = 8
        let stack = NSStackView(views: [header, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use init(owner:)") }

    func update(_ note: TextDocument, delay: TimeInterval = 0.15) {
        cancel()
        let generation = self.generation
        let id = note.id
        let revision = note.revision
        let source = note.text
        let size = Preferences.fontSize
        label.stringValue = L("Aktualizace náhledu…", "Updating preview…")
        if renderedNoteID != id { textView.string = "" }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let operation, !operation.isCancelled else { return }
            let result = Result { try MarkdownRenderer.render(source, fontSize: size) }
            DispatchQueue.main.async {
                guard let self, self.generation == generation, !operation.isCancelled,
                      self.owner?.active?.id == id, self.owner?.active?.revision == revision else { return }
                switch result {
                case .success(let rendered):
                    self.textView.textStorage?.setAttributedString(rendered)
                    self.renderedNoteID = id
                    self.renderedRevision = revision
                    self.label.stringValue = L("Náhled Markdownu", "Markdown preview")
                case .failure(let error):
                    self.textView.string = error.localizedDescription
                    self.label.stringValue = L("Náhled nelze zobrazit", "Preview unavailable")
                }
            }
        }
        let work = DispatchWorkItem { [weak self] in self?.queue.addOperation(operation) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancel() {
        generation += 1
        pending?.cancel()
        queue.cancelAllOperations()
    }

    @objc func closePreview(_ sender: Any?) { owner?.toggleMarkdownPreview(sender) }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = MarkdownRenderer.allowedLink(link) { NSWorkspace.shared.open(url) }
        return true
    }
}

final class MarkdownTextView: NSTextView {
    weak var preview: MarkdownPreview?
    override func cancelOperation(_ sender: Any?) { preview?.closePreview(sender) }
}

extension EditorWindowController {
    @objc func toggleMarkdownPreview(_ sender: Any?) {
        captureSelection()
        if let markdownPreview { markdownPreview.cancel(); self.markdownPreview = nil }
        else { markdownPreview = MarkdownPreview(owner: self) }
        refresh()
    }

    func installEditorContent(_ editor: NSView) {
        let content: NSView
        if let preview = markdownPreview {
            let stack = NSStackView(views: [editor, preview])
            stack.orientation = .horizontal
            stack.distribution = .fillEqually
            stack.spacing = 1
            stack.alignment = .top
            for child in stack.arrangedSubviews { child.heightAnchor.constraint(equalTo: stack.heightAnchor).isActive = true }
            content = stack
            if let active { preview.update(active, delay: 0) }
        } else { content = editor }
        content.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            content.topAnchor.constraint(equalTo: body.topAnchor),
            content.bottomAnchor.constraint(equalTo: body.bottomAnchor)
        ])
    }
}
