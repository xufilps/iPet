// SPDX-License-Identifier: Apache-2.0
/// The persistent base animation restored after transient feedback; never settles economy.
public struct PetPresentation: Equatable, Sendable {
    public let action: PetAction
    public let graphID: String?
    public init(state: PetState, catalog: PetCatalog) {
        if state.resting { action = .sleep; graphID = nil }
        else if let session=state.activity, !session.isPaused, let activity=catalog.activity(session.activityID) {
            action = .activity; graphID = activity.graphID
        } else { action = .idle; graphID = nil }
    }
}
