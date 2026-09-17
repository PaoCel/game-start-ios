import SwiftUI

struct FloatingParticles: View {
    private let symbols = ["♠", "♥", "♦", "♣"]
    @State private var isKeyboardVisible = false

    var body: some View {
        GeometryReader { geo in
            if !isKeyboardVisible {
                TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ForEach(0..<8, id: \.self) { index in
                            let baseX = pseudoRandom(index: index * 17) * geo.size.width
                            let drift = sin(t * 0.3 + Double(index)) * 18
                            let duration = 15.0 + pseudoRandom(index: index * 11) * 10
                            let progress = (t.truncatingRemainder(dividingBy: duration)) / duration
                            let y = geo.size.height - (geo.size.height + 30) * progress
                            let size = 4 + pseudoRandom(index: index * 7) * 6

                            Text(symbols[index % symbols.count])
                                .font(.system(size: size))
                                .foregroundStyle(BorderlandTheme.textDim.opacity(0.10 + pseudoRandom(index: index * 3) * 0.15))
                                .position(x: baseX + drift, y: y)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private func pseudoRandom(index: Int) -> Double {
        let seed = Double((index * 1103515245 + 12345) & 0x7fffffff)
        return (seed.truncatingRemainder(dividingBy: 1000)) / 1000
    }
}
