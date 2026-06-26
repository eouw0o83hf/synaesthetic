import SwiftUI

struct ContentView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Circle()
                    .fill(.red)
                    .frame(width: radiusSize(geometry), height: radiusSize(geometry))
            }
        }
    }

    private func radiusSize(_ geometry: GeometryProxy) -> CGFloat {
        let minDimension = min(geometry.size.width, geometry.size.height)
        return minDimension * 0.6
    }
}

#Preview {
    ContentView()
}
