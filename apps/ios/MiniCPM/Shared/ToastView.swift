import MiniCPMCore
import SwiftUI

/// iOS has no system toast, so this is the one custom piece of feedback. Undo lives here instead of confirmations.
struct ToastView: View {
    @Environment(AppModel.self) private var model
    /// Sheets cover the root, so they show their own copy. Only the root one speaks.
    var announces = true

    var body: some View {
        if let toast = model.toast {
            HStack(spacing: 12) {
                Text(Copy.notice(toast.notice)).font(.subheadline)
                if let action = toast.action {
                    Button(Copy.toastAction(action.kind)) { model.runToastAction() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.horizontal, 16)
            .padding(.bottom, 92)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: toast.id) {
                if announces { AccessibilityNotification.Announcement(Copy.notice(toast.notice)).post() }
                try? await Task.sleep(for: toast.action == nil ? .seconds(3.2) : .seconds(7))
                if !Task.isCancelled { model.dismissToast() }
            }
        }
    }
}
