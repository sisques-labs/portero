import AppKit

/// A search field wrapped as a plain NSView so it can be used as a custom NSMenuItem view.
final class FilterFieldView: NSView, NSSearchFieldDelegate {
    private let searchField = NSSearchField()

    var onTextChange: ((String) -> Void)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        searchField.frame = NSRect(x: 14, y: 4, width: 192, height: 22)
        searchField.placeholderString = "Filter by port or process"
        searchField.delegate = self
        addSubview(searchField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func controlTextDidChange(_ notification: Notification) {
        onTextChange?(searchField.stringValue)
    }
}
