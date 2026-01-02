import SwiftUI

struct StatusButton: View {
    @ObservedObject var display: DisplayInfo
    @EnvironmentObject var viewModel: DisplaysViewModel
    @EnvironmentObject var errorHandler: ErrorHandler
    
    @State private var isAnimating = false
    private var statusText: String {
        switch display.state {
        case .mirrored:
            return "Mirrored"
        case .disconnected:
            return "Disabled"
        case .active:
            return "Active"
        case .pending:
            return "Pending"
        }
    }
    
    private var statusColor: Color {
        switch display.state {
        case .mirrored:
            return Color("AppRed-Bright")
        case .disconnected:
            return Color("AppRed")
        case .active:
            return Color("AppGreen")
        case .pending:
            return Color("AppBlue")
        }
    }
    
    private func hasAnotherActiveDisplay() -> Bool {
        viewModel.displays
            .filter { $0.id != display.id }
            .contains { $0.state == .active }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor)
                .frame(width: 90, height: 32)

            if display.state == .pending {
                Text("Pending")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(isAnimating ? .white : .gray)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            isAnimating.toggle()
                        }
                    }
            } else {
                Text(statusText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            }
        }
        .onTapGesture {
            if display.state == .pending { return }

            // Check if the Shift key is pressed
            let shiftPressed = NSEvent.modifierFlags.contains(.shift)

            if shiftPressed {
                handleShiftTap()
            } else {
                handleTap()
            }
        }
    }

    private func handleTap() {
        do {
            if display.state.isOff() {
                try viewModel.turnOnDisplay(display: display)
            } else {
                guard hasAnotherActiveDisplay() else { return }
                try viewModel.disconnectDisplay(display: display)
            }
        } catch let error {
            errorHandler.handle(error: error) {
                viewModel.displays.remove(at: viewModel.displays.firstIndex(of: display)!)
                viewModel.resetAllDisplays()
                viewModel.fetchDisplays()
            }
        }
        

    }

    private func handleShiftTap() {
        do {
            if display.state.isOff() {
                try viewModel.turnOnDisplay(display: display)
            } else {
                guard hasAnotherActiveDisplay() else { return }
                try viewModel.disableDisplay(display: display)
            }
        } catch let error {
            errorHandler.handle(error: error) {
                viewModel.displays.remove(at: viewModel.displays.firstIndex(of: display)!)
                viewModel.resetAllDisplays()
                viewModel.fetchDisplays()
            }
        }
    }
}
