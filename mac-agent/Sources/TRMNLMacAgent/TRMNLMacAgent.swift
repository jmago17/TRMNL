import AppKit
import EventKit
import Foundation
import Photos

@main
struct TRMNLMacAgent {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            guard let command = arguments.first else {
                print(Usage.text)
                return
            }
            Log.info("Starting command: \(command)")
            defer { Log.info("Finished command: \(command)") }

            let options = try Options(arguments: Array(arguments.dropFirst()))

            switch command {
            case "example-config":
                print(Config.exampleJSON)
            case "list-calendars":
                let runner = Runner(config: .empty)
                try await runner.listCalendars()
            case "day-agenda":
                let runner = try Runner(options: options)
                try await runner.sendDayAgenda(for: options.dateValue(for: "date") ?? Date())
            case "week-overview":
                let runner = try Runner(options: options)
                try await runner.sendWeekOverview(for: options.dateValue(for: "date") ?? Date())
            case "month-overview":
                let runner = try Runner(options: options)
                try await runner.sendMonthOverview(for: options.dateValue(for: "date") ?? Date())
            case "photo-file":
                let runner = try Runner(options: options)
                guard let path = options.positional.first else {
                    throw AgentError.usage("Missing image path.")
                }
                let delivery = try PhotoDelivery.parse(options.value(for: "delivery"))
                try await runner.sendPhotoFile(
                    path: path,
                    filename: options.value(for: "filename") ?? "photo.jpg",
                    delivery: delivery
                )
            case "photo-library":
                let runner = try Runner(options: options)
                let mode = PhotoPickMode(rawValue: options.value(for: "mode") ?? "latest") ?? .latest
                let delivery = try PhotoDelivery.parse(options.value(for: "delivery"))
                try await runner.sendPhotoFromLibrary(
                    albumName: options.value(for: "album"),
                    mode: mode,
                    filename: options.value(for: "filename") ?? "photo.jpg",
                    delivery: delivery
                )
            case "slideshow-library":
                let runner = try Runner(options: options)
                let type = try SlideshowType.parse(options.value(for: "type"))
                let limit = Int(options.value(for: "limit") ?? "") ?? 5
                let mode = PhotoPickMode(rawValue: options.value(for: "mode") ?? "random") ?? .random
                try await runner.uploadSlideshowFromLibrary(
                    type: type,
                    albumName: options.value(for: "album"),
                    limit: min(max(limit, 1), 5),
                    mode: mode
                )
            case "slideshow-both":
                let runner = try Runner(options: options)
                let limit = Int(options.value(for: "limit") ?? "") ?? 5
                let mode = PhotoPickMode(rawValue: options.value(for: "mode") ?? "random") ?? .random
                try await runner.uploadBothSlideshowsFromLibrary(
                    albumName: options.value(for: "album"),
                    limit: min(max(limit, 1), 5),
                    mode: mode
                )
            case "help", "--help", "-h":
                print(Usage.text)
            default:
                throw AgentError.usage("Unknown command: \(command)")
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

private struct Runner {
    let config: Config

    init(config: Config) {
        self.config = config
    }

    init(options: Options) throws {
        self.config = try Config.load(from: options.value(for: "config"))
    }

    func listCalendars() async throws {
        let service = CalendarService(config: config)
        try await service.requestAccess()
        for calendar in service.availableCalendars() {
            print("\(calendar.calendarIdentifier)\t\(calendar.title)")
        }
    }

    func sendDayAgenda(for date: Date) async throws {
        try NetworkPreflight.requireNetwork()
        let calendarService = CalendarService(config: config)
        try await calendarService.requestAccess()
        let payload = calendarService.dayAgendaPayload(for: date)
        try await WebhookService(config: config).sendDayAgenda(title: payload.title, events: payload.events)
        print("Day agenda sent.")
    }

    func sendWeekOverview(for date: Date) async throws {
        try NetworkPreflight.requireNetwork()
        let calendarService = CalendarService(config: config)
        try await calendarService.requestAccess()
        let payload = calendarService.weekOverviewPayload(for: date)
        try await WebhookService(config: config).sendWeekOverview(weekTitle: payload.weekTitle, days: payload.days)
        print("Week overview sent.")
    }

    func sendMonthOverview(for date: Date) async throws {
        try NetworkPreflight.requireNetwork()
        let calendarService = CalendarService(config: config)
        try await calendarService.requestAccess()
        let payload = calendarService.monthOverviewPayload(for: date)
        try await WebhookService(config: config).sendMonthOverview(
            monthTitle: payload.monthTitle,
            headers: payload.headers,
            weeks: payload.weeks
        )
        print("Month overview sent.")
    }

    func sendPhotoFile(path: String, filename: String, delivery: PhotoDelivery) async throws {
        try NetworkPreflight.requireNetwork()
        let image = try ImageService.loadImage(at: path)
        let data = try ImageService.processJPEG(image)
        let imageURL = try await UploadService(config: config).upload(imageData: data, filename: filename)
        try await deliverPhoto(imageURL: imageURL, delivery: delivery)
    }

    func sendPhotoFromLibrary(albumName: String?, mode: PhotoPickMode, filename: String, delivery: PhotoDelivery) async throws {
        try NetworkPreflight.requireNetwork()
        let photoService = PhotoLibraryService()
        try await photoService.requestAccess()
        let image = try await photoService.pickImage(albumName: albumName, mode: mode)
        let data = try ImageService.processJPEG(image)
        let imageURL = try await UploadService(config: config).upload(imageData: data, filename: filename)
        try await deliverPhoto(imageURL: imageURL, delivery: delivery)
    }

    func uploadSlideshowFromLibrary(type: SlideshowType, albumName: String?, limit: Int, mode: PhotoPickMode) async throws {
        try NetworkPreflight.requireNetwork()
        let photoService = PhotoLibraryService()
        try await photoService.requestAccess()
        let images = try await photoService.pickImages(albumName: albumName, type: type, limit: limit, mode: mode)
        try await upload(images: images, type: type)

        print("\(images.count) \(type.rawValue) slideshow photo(s) uploaded.")
    }

    func uploadBothSlideshowsFromLibrary(albumName: String?, limit: Int, mode: PhotoPickMode) async throws {
        try NetworkPreflight.requireNetwork()
        let photoService = PhotoLibraryService()
        try await photoService.requestAccess()
        let grouped = try await photoService.pickSlideshowImages(albumName: albumName, limitPerType: limit, mode: mode)
        try await upload(images: grouped.landscape, type: .landscape)
        try await upload(images: grouped.portrait, type: .portrait)

        print("\(grouped.landscape.count) landscape slideshow photo(s) uploaded.")
        print("\(grouped.portrait.count) portrait slideshow photo(s) uploaded.")
        print("Landscape polling URL: \(config.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/slideshow?type=landscape&count=\(grouped.landscape.count)")
        print("Portrait polling URL: \(config.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/slideshow?type=portrait&count=\(grouped.portrait.count)")
    }

    private func upload(images: [NSImage], type: SlideshowType) async throws {
        let uploader = UploadService(config: config)
        for (index, image) in images.enumerated() {
            let data = try ImageService.processJPEG(image)
            _ = try await uploader.upload(imageData: data, filename: "\(type.rawValue)-\(index + 1).jpg")
        }
    }

    private func deliverPhoto(imageURL: String, delivery: PhotoDelivery) async throws {
        switch delivery {
        case .polling:
            print("Photo uploaded for polling: \(imageURL)")
            print("Use this TRMNL polling URL: \(config.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/photo")
        case .webhook:
            try await WebhookService(config: config).sendPhoto(imageURL: imageURL)
            print("Photo sent.")
        }
    }
}

private struct Usage {
    static let text = """
    TRMNL Mac Agent

    Usage:
      trmnl-mac-agent example-config
      trmnl-mac-agent list-calendars [--config path]
      trmnl-mac-agent day-agenda [--date yyyy-mm-dd] [--config path]
      trmnl-mac-agent week-overview [--date yyyy-mm-dd] [--config path]
      trmnl-mac-agent month-overview [--date yyyy-mm-dd] [--config path]
      trmnl-mac-agent photo-file /path/to/image.jpg [--filename photo.jpg] [--delivery polling|webhook] [--config path]
      trmnl-mac-agent photo-library [--album name] [--mode latest|random] [--filename photo.jpg] [--delivery polling|webhook] [--config path]
      trmnl-mac-agent slideshow-library --type portrait|landscape [--album name] [--limit 5] [--mode random|latest] [--config path]
      trmnl-mac-agent slideshow-both [--album name] [--limit 5] [--mode random|latest] [--config path]

    Default config path:
      ~/.config/trmnl-mac-agent/config.json
    """
}
