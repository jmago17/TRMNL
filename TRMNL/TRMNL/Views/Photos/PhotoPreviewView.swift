import SwiftUI

struct PhotoPreviewView: View {
    let original: UIImage
    let dithered: UIImage

    @State private var showDithered = true

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Image(uiImage: showDithered ? dithered : original)
                    .resizable()
                    .aspectRatio(CGSize(width: 800, height: 480), contentMode: .fit)
                    .border(Color.primary.opacity(0.2))
            }
            .padding(.horizontal)

            Picker("Preview", selection: $showDithered) {
                Text("Original").tag(false)
                Text("Dithered (e-ink)").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}
