import WidgetKit
import SwiftUI

@main
struct NavigationWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            NavigationWidgetLiveActivity()
        }
    }
}
