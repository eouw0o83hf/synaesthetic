import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Emitter(
                radiusPercent: 0.3,
                color: .red,
                highlightColor: .orange
            )
        }
    }
}

#Preview {
    ContentView()
}
