import Foundation
import UIKit

/// Fetches a festival image for the offline copy: only an HTTP 200 that decodes as an image is
/// kept, downscaled to 1600 px on its longest side and re-encoded as JPEG.
enum OfflineImage {
    static let maxSide: CGFloat = 1600

    struct Unusable: Error {}

    static func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else {
            throw Unusable()
        }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw Unusable() }
        return jpeg
    }
}
