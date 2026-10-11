import AppKit

enum NotepadColors {
    static let canvas = NSColor.textBackgroundColor
    static let chrome = NSColor.windowBackgroundColor
    static let hover = NSColor.labelColor.withAlphaComponent(0.07)
    static let warningText = NSColor(name: nil) { appearance in
        var color = NSColor.labelColor
        appearance.performAsCurrentDrawingAppearance {
            color = NSColor.systemRed.blended(withFraction: 0.4, of: .labelColor) ?? .labelColor
        }
        return color
    }
}

class ChromeSurface: NSView {
    var color: NSColor = NotepadColors.canvas
    var bottomBorder = false
    var topBorder = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        let pixel = 1 / (window?.backingScaleFactor ?? 2)
        if bottomBorder { NSRect(x: 0, y: 0, width: bounds.width, height: pixel).fill() }
        if topBorder { NSRect(x: 0, y: bounds.height - pixel, width: bounds.width, height: pixel).fill() }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

final class NotepadTitlebar: NSVisualEffectView {
    override var mouseDownCanMoveWindow: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .titlebar
        blendingMode = .withinWindow
        state = .followsWindowActiveState
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
}

class ChromeButton: NSButton {
    override var mouseDownCanMoveWindow: Bool { false }
    private var tracking: NSTrackingArea?
    private var hovered = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        bezelStyle = .inline
        font = .systemFont(ofSize: 13)
        contentTintColor = .labelColor
        setButtonType(.momentaryPushIn)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hovered || isHighlighted {
            NotepadColors.hover.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 2), xRadius: 5, yRadius: 5).fill()
        }
        super.draw(dirtyRect)
    }
}

final class ChromeMenuButton: ChromeButton {
    var menuProvider: (() -> NSMenu?)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        target = self
        action = #selector(openMenu(_:))
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    @objc private func openMenu(_ sender: Any?) {
        guard let menu = menuProvider?() else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: self)
    }
}

final class SearchResultsStack: NSStackView {
    override var isFlipped: Bool { true }
    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: widthAnchor, constant: -24).isActive = true
        if let button = view as? NSButton {
            button.alignment = .left
            button.font = .systemFont(ofSize: 12)
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            button.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.contentTintColor = .labelColor
        } else if let label = view as? NSTextField {
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }
    }
}

final class NotepadStatusBar: ChromeSurface {
    let position = NSTextField(labelWithString: "")
    let count = NSTextField(labelWithString: "")
    let zoom = NSTextField(labelWithString: "100 %")
    let encoding = NSTextField(labelWithString: "UTF-8")
    let lineEnding = NSTextField(labelWithString: "CRLF")
    private let row = NSStackView()
    private let countDivider = NSBox()
    var hasWarning = false { didSet { needsLayout = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        color = NotepadColors.chrome
        topBorder = true
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        for label in [position, count, zoom, encoding, lineEnding] {
            label.font = .systemFont(ofSize: 11)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        position.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        position.setAccessibilityIdentifier("document-status")
        row.addArrangedSubview(position)
        addDivider(countDivider)
        row.addArrangedSubview(count)
        let space = NSView()
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(space)
        row.addArrangedSubview(zoom)
        addDivider(NSBox())
        row.addArrangedSubview(encoding)
        addDivider(NSBox())
        row.addArrangedSubview(lineEnding)
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    private func addDivider(_ divider: NSBox) {
        divider.boxType = .separator
        row.addArrangedSubview(divider)
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 12).isActive = true
    }

    override func layout() {
        let hideCount = bounds.width < 680 || hasWarning
        count.isHidden = hideCount
        countDivider.isHidden = hideCount
        super.layout()
    }
}
