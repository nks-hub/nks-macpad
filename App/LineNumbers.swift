import AppKit

final class LineNumbers: NSRulerView {
    weak var editor: NSTextView?

    init(scrollView: NSScrollView, editor: NSTextView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clipsToBounds = true
        ruleThickness = 48
        clientView = editor
    }
    required init(coder: NSCoder) { fatalError("Use init(scrollView:editor:)") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.intersection(rect).fill()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.labelColor]
        for (number, point) in visibleLineLabels() {
            let label = "\(number)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: point.y), withAttributes: attributes)
        }
    }

    func visibleLineLabels() -> [(number: Int, origin: NSPoint)] {
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return [] }
        let text = editor.string as NSString
        let visible = editor.visibleRect.offsetBy(dx: -editor.textContainerOrigin.x, dy: -editor.textContainerOrigin.y)
        layout.ensureLayout(forBoundingRect: visible, in: container)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var location = text.lineRange(for: NSRange(location: min(characters.location, text.length), length: 0)).location
        let cached = (editor as? EditorTextView).flatMap { view in view.owner?.cachedLine(at: location, in: view) }
        var number = cached?.line ?? editor.string.utf16.prefix(location).reduce(1) { $1 == 10 ? $0 + 1 : $0 }
        var labels: [(number: Int, origin: NSPoint)] = []
        while location < text.length && location <= NSMaxRange(characters) {
            let glyph = layout.glyphIndexForCharacter(at: location)
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let point = convert(NSPoint(x: 0, y: fragment.minY + editor.textContainerOrigin.y), from: editor)
            labels.append((number, point))
            location = NSMaxRange(text.lineRange(for: NSRange(location: location, length: 0)))
            number += 1
        }
        if text.length == 0 || editor.string.hasSuffix("\n") {
            let fragment = layout.extraLineFragmentRect
            if fragment.intersects(visible) || text.length == 0 {
                let finalNumber = cached?.total ?? editor.string.utf16.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
                let point = convert(NSPoint(x: 0, y: fragment.minY + editor.textContainerOrigin.y), from: editor)
                labels.append((finalNumber, point))
            }
        }
        return labels
    }
}

extension EditorWindowController {
    @objc func toggleLineNumbers(_ sender: Any?) {
        UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "lineNumbers"), forKey: "lineNumbers")
        app.editors.forEach { editor in editor.allTextViews.forEach { editor.configure($0) } }
    }
}
