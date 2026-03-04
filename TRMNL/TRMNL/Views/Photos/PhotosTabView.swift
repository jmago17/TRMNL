import PhotosUI
import SwiftUI

struct PhotosTabView: View {
    @State private var slideshowType: SlideshowType = .landscape
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var ditheredPhotos: [UIImage] = []
    @State private var isProcessing = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let imageService = ImageProcessingService()
    private let uploadService = CloudflareUploadService()

    private var slideshowURL: String {
        let base = AppSettings.shared.workerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/slideshow?type=\(slideshowType.rawValue)&count=\(ditheredPhotos.count)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Type", selection: $slideshowType) {
                    ForEach(SlideshowType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: slideshowType) { _, _ in
                    selectedItems = []
                    ditheredPhotos = []
                }

                if ditheredPhotos.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Photos Selected",
                        systemImage: "photo.stack",
                        description: Text("Pick up to 5 \(slideshowType.label.lowercased()) to cycle on your TRMNL display.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(ditheredPhotos.enumerated()), id: \.offset) { index, photo in
                                VStack(spacing: 4) {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .aspectRatio(CGSize(width: 800, height: 480), contentMode: .fit)
                                        .border(Color.primary.opacity(0.2))
                                    Text("Photo \(index + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                }

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label(
                        ditheredPhotos.isEmpty ? "Choose Photos (up to 5)" : "Change Photos",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .disabled(isProcessing || isUploading)

                if !ditheredPhotos.isEmpty {
                    Button {
                        Task { await uploadAll() }
                    } label: {
                        HStack {
                            if isUploading { ProgressView().tint(.white) }
                            Text(isUploading ? "Uploading..." : "Upload \(ditheredPhotos.count) \(slideshowType.label) to TRMNL")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading || isProcessing || !AppSettings.shared.isConfigured)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Photos")
            .overlay {
                if isProcessing { ProgressView("Processing...") }
            }
            .onChange(of: selectedItems) { _, items in
                Task { await processPhotos(items) }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Uploaded!", isPresented: .init(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil } }
            )) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    private func processPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessing = true
        defer { isProcessing = false }

        var processed: [UIImage] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { continue }
            let photo = await imageService.processForDisplay(uiImage)
            processed.append(photo)
        }
        ditheredPhotos = processed
    }

    private func uploadAll() async {
        isUploading = true
        defer { isUploading = false }

        var uploadedCount = 0
        for (index, photo) in ditheredPhotos.enumerated() {
            guard let jpegData = await imageService.jpegData(from: photo) else { continue }
            do {
                _ = try await uploadService.upload(imageData: jpegData, filename: "\(slideshowType.rawValue)-\(index + 1).jpg")
                uploadedCount += 1
            } catch {
                errorMessage = "Upload failed on photo \(index + 1): \(error.localizedDescription)"
                return
            }
        }

        successMessage = "\(uploadedCount) \(slideshowType.label.lowercased()) uploaded.\n\nSet your TRMNL plugin to poll:\n\(slideshowURL)"
    }
}
