import CoreGraphics

public struct PixelScaler {
    public static let virtualSize = CGSize(width: 360, height: 640)

    public struct Result {
        public let scale: CGFloat
        public let contentSize: CGSize
    }

    public static func scaledContentSize(for availableSize: CGSize) -> Result {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return Result(scale: 1, contentSize: virtualSize)
        }

        let widthScale = floor(availableSize.width / virtualSize.width)
        let heightScale = floor(availableSize.height / virtualSize.height)
        let scale = max(1, min(widthScale, heightScale))
        let contentSize = CGSize(width: virtualSize.width * scale, height: virtualSize.height * scale)
        return Result(scale: scale, contentSize: contentSize)
    }
}
