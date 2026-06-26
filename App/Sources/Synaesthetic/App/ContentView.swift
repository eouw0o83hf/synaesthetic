import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "app.gift.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Synaesthetic")
                        .font(.largeTitle.bold())

                    Text("Start building your app here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Synaesthetic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
