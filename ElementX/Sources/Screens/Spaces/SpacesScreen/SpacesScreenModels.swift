//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum SpacesScreenViewModelAction {
    case selectSpace(SpaceRoomListProxyProtocol)
    case selectRoom(roomID: String)
    case showSettings
    case showCreateSpace
}

struct SpacesScreenViewState: BindableState {
    let userID: String
    var userDisplayName: String?
    var userAvatarURL: URL?

    var topLevelSpaces: [SpaceServiceRoom]
    var selectedSpaceID: String?
    var selectedSpaceMembers: [RoomMemberDetails]?

    var selectedSpace: SpaceServiceRoom? {
        if let selectedSpaceID,
           let selectedSpace = topLevelSpaces.first(where: { $0.id == selectedSpaceID }) {
            return selectedSpace
        }

        return topLevelSpaces.first
    }
}

enum SpacesScreenViewAction {
    case selectSpace(SpaceServiceRoom)
    case openSpaceDetails(SpaceServiceRoom)
    case selectMember(RoomMemberDetails)
    case showSettings
    case createSpace
}
