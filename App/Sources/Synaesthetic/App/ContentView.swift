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

            VStack {
                HStack {
                    Spacer()
                    Emitter(
                        radiusPercent: 0.2,
                        color: .blue,
                        highlightColor: .green
                    )
                    .frame(width: 200, height: 200)
                }
                Spacer()
                HStack {
                    Emitter(
                        radiusPercent: 0.27,
                        color: .purple,
                        highlightColor: .red
                    )
                    .frame(width: 250, height: 250)
                    Spacer()
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
