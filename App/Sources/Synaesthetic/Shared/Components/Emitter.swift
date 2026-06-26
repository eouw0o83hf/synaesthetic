import SwiftUI

/// A circle with an angular gradient that wraps around with a sharp radial edge.
/// The radius is a percentage of the smaller screen dimension.
struct Emitter: View {
    /// The radius as a percentage of the smaller screen dimension (0.0 to 1.0).
    let radiusPercent: CGFloat

    /// The starting color of the gradient.
    let color: Color

    /// The highlight color that the gradient fades to.
    let highlightColor: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [color, highlightColor],
                            center: .center
                        )
                    )
                    .frame(
                        width: calculateDiameter(for: geometry),
                        height: calculateDiameter(for: geometry)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Calculates the diameter (2x radius) based on the radius percentage.
    private func calculateDiameter(for geometry: GeometryProxy) -> CGFloat {
        let minDimension = min(geometry.size.width, geometry.size.height)
        return minDimension * radiusPercent * 2
    }
}

#Preview {
    Emitter(
        radiusPercent: 0.3,
        color: .red,
        highlightColor: .orange
    )
    .background(.black)
}
