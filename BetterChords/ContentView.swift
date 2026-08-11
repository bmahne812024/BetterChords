import SwiftUI

struct ContentView: View {
    let lessonTitle = "Bb13"

    @State private var selectedImageType: ChordImageType = .rhExtension

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text(lessonTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.top, 20)

                VideoPlaceholderView()
                    .frame(height: 220)
                    .padding(.horizontal, 20)

                Picker("Chord View", selection: $selectedImageType) {
                    ForEach(ChordImageType.allCases) { imageType in
                        Text(imageType.displayName)
                            .tag(imageType)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                ChordImageView(imageURL: selectedImageType.imageURL)
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

enum ChordImageType: String, CaseIterable, Identifiable {
    case rhExtension
    case rhScale

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .rhExtension:
            return "RH extension"
        case .rhScale:
            return "RH scale"
        }
    }

    var imageURL: URL {
        switch self {
        case .rhExtension:
            return URL(string: "https://firebasestorage.googleapis.com/v0/b/betterchords.firebasestorage.app/o/LH%20Chords%2F13%20with%20extension%2FBb13%20extension.png?alt=media&token=b2868268-8f4d-442f-bd2d-4c08e4565f83")!

        case .rhScale:
            return URL(string: "https://firebasestorage.googleapis.com/v0/b/betterchords.firebasestorage.app/o/LH%20Chords%2F13%20with%20scale%2FBb13%20with%20scale.png?alt=media&token=ab69f724-6b21-4371-9bc7-4e4546efce0e")!
        }
    }
}

struct VideoPlaceholderView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.7), lineWidth: 2)
                )

            VStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Video goes here")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

struct ChordImageView: View {
    let imageURL: URL

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.orange)
                    .frame(maxWidth: .infinity, minHeight: 220)

            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 2)
                    )

            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)

                    Text("Could not load chord image")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            @unknown default:
                EmptyView()
            }
        }
    }
}

#Preview {
    ContentView()
}
