import SwiftUI

extension Theme {
    enum Font {
        static let display = SwiftUI.Font.system(size: 34, weight: .black, design: .rounded)
        static let title = SwiftUI.Font.system(size: 22, weight: .bold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 13, weight: .medium)
        static let stat = SwiftUI.Font.system(size: 28, weight: .heavy, design: .monospaced)
    }
}
