import SwiftUI

struct SidebarPullRequestMetadata: View {
    let pullRequest: PullRequest

    var body: some View {
        if let status {
            HStack(spacing: 5) {
                Image(systemName: status.systemImage)
                    .foregroundStyle(status.color)

                Text(status.title)
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .regular))
            .lineLimit(1)
        }
    }

    private var status: MetadataStatus? {
        if pullRequest.mergeable == .conflicting {
            return .mergeConflicts
        }

        return checkStatus
    }

    private var checkStatus: MetadataStatus? {
        switch pullRequest.statusCheckRollup?.state {
        case .error, .failure:
            return .checksFailing
        case .expected, .pending:
            return .checksPending
        case .success:
            return .checksPassing
        case nil:
            return nil
        }
    }

}

private enum MetadataStatus {
    case mergeConflicts
    case checksFailing
    case checksPending
    case checksPassing

    var title: String {
        switch self {
        case .mergeConflicts:
            return "Merge conflicts"
        case .checksFailing:
            return "Checks failing"
        case .checksPending:
            return "Checks pending"
        case .checksPassing:
            return "Checks passing"
        }
    }

    var systemImage: String {
        switch self {
        case .mergeConflicts:
            return "exclamationmark.triangle.fill"
        case .checksFailing:
            return "xmark.circle.fill"
        case .checksPending:
            return "clock.fill"
        case .checksPassing:
            return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .mergeConflicts, .checksPending:
            return Color(red: 0.62, green: 0.40, blue: 0.00)
        case .checksFailing:
            return Color(red: 0.82, green: 0.14, blue: 0.16)
        case .checksPassing:
            return Color(red: 0.10, green: 0.50, blue: 0.22)
        }
    }
}
