import AppIntents

enum SlideshowType: String, AppEnum, CaseIterable {
    case portrait
    case landscape

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Slideshow Type")
    static var caseDisplayRepresentations: [SlideshowType: DisplayRepresentation] = [
        .portrait: "Portraits",
        .landscape: "Landscapes"
    ]

    var label: String {
        switch self {
        case .portrait: return "Portraits"
        case .landscape: return "Landscapes"
        }
    }
}
