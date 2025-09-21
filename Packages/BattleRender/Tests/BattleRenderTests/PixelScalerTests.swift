import CoreGraphics
import Testing
@testable import BattleRender

@Test("Scaler returns at least 1")
func scalerMinimumScale() {
    let result = PixelScaler.scaledContentSize(for: .zero)
    #expect(result.scale == 1)
    #expect(result.contentSize == PixelScaler.virtualSize)
}

@Test("Scaler computes integer scale for common device sizes")
func scalerForCommonDevices() {
    // iPhone SE (2nd gen) portrait: 375 × 667
    let se = PixelScaler.scaledContentSize(for: CGSize(width: 375, height: 667))
    #expect(se.scale == 1)
    #expect(se.contentSize == PixelScaler.virtualSize)

    // iPhone 14 portrait: 390 × 844
    let iphone14 = PixelScaler.scaledContentSize(for: CGSize(width: 390, height: 844))
    #expect(iphone14.scale == 1)

    // iPad mini portrait: 744 × 1133 -> height limits scale to 1
    let ipadMini = PixelScaler.scaledContentSize(for: CGSize(width: 744, height: 1133))
    #expect(ipadMini.scale == 1)
    #expect(ipadMini.contentSize == PixelScaler.virtualSize)
}
