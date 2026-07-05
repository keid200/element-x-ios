//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

typealias SpacesScreenViewModelType = StateStoreViewModelV2<SpacesScreenViewState, SpacesScreenViewAction>

class SpacesScreenViewModel: SpacesScreenViewModelType, SpacesScreenViewModelProtocol {
    private let spaceServiceProxy: SpaceServiceProxyProtocol
    private let clientProxy: ClientProxyProtocol
    private let appSettings: AppSettings
    private let userIndicatorController: UserIndicatorControllerProtocol
    private var selectedSpaceMembersCancellable: AnyCancellable?
    private var knownDirectRoomIDs = [String: String]()
    private var pendingDirectChatUserIDs = Set<String>()

    private let actionsSubject: PassthroughSubject<SpacesScreenViewModelAction, Never> = .init()
    var actionsPublisher: AnyPublisher<SpacesScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(userSession: UserSessionProtocol,
         selectedSpacePublisher: CurrentValuePublisher<String?, Never>,
         appSettings: AppSettings,
         userIndicatorController: UserIndicatorControllerProtocol) {
        spaceServiceProxy = userSession.clientProxy.spaceService
        clientProxy = userSession.clientProxy
        self.appSettings = appSettings
        self.userIndicatorController = userIndicatorController

        super.init(initialViewState: SpacesScreenViewState(userID: userSession.clientProxy.userID,
                                                           topLevelSpaces: spaceServiceProxy.topLevelSpacesPublisher.value),
                   mediaProvider: userSession.mediaProvider)

        spaceServiceProxy.topLevelSpacesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] spaces in
                guard let self else { return }
                state.topLevelSpaces = spaces

                if let selectedSpaceID = state.selectedSpaceID,
                   spaces.contains(where: { $0.id == selectedSpaceID }) {
                    return
                }

                guard let firstSpace = spaces.first else {
                    state.selectedSpaceID = nil
                    state.selectedSpaceMembers = nil
                    return
                }

                selectSpaceInPlace(firstSpace)
            }
            .store(in: &cancellables)

        selectedSpacePublisher
            .compactMap { $0 }
            .sink { [weak self] selectedSpaceID in
                guard let self,
                      let selectedSpace = state.topLevelSpaces.first(where: { $0.id == selectedSpaceID }) else {
                    return
                }

                selectSpaceInPlace(selectedSpace)
            }
            .store(in: &cancellables)

        userSession.clientProxy.userAvatarURLPublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userAvatarURL, on: self)
            .store(in: &cancellables)

        userSession.clientProxy.userDisplayNamePublisher
            .receive(on: DispatchQueue.main)
            .weakAssign(to: \.state.userDisplayName, on: self)
            .store(in: &cancellables)

        if let firstSpace = state.topLevelSpaces.first {
            selectSpaceInPlace(firstSpace)
        }
    }

    // MARK: - Public

    override func process(viewAction: SpacesScreenViewAction) {
        MXLog.info("View model: received view action: \(viewAction)")

        switch viewAction {
        case .selectSpace(let spaceServiceRoom):
            selectSpaceInPlace(spaceServiceRoom)
        case .openSpaceDetails(let spaceServiceRoom):
            Task { await selectSpace(spaceServiceRoom) }
        case .selectMember(let member):
            Task { await openDirectChat(with: member) }
        case .showSettings:
            actionsSubject.send(.showSettings)
        case .createSpace:
            actionsSubject.send(.showCreateSpace)
        }
    }

    // MARK: - Private

    private func selectSpaceInPlace(_ spaceServiceRoom: SpaceServiceRoom) {
        state.selectedSpaceID = spaceServiceRoom.id
        state.selectedSpaceMembers = nil
        Task { await loadMembers(in: spaceServiceRoom.id) }
    }

    private func loadMembers(in roomID: String) async {
        selectedSpaceMembersCancellable = nil

        guard case let .joined(roomProxy) = await clientProxy.roomForIdentifier(roomID) else {
            if state.selectedSpaceID == roomID {
                state.selectedSpaceMembers = []
            }
            return
        }

        await roomProxy.updateMembers()

        guard state.selectedSpaceID == roomID else { return }

        selectedSpaceMembersCancellable = roomProxy.membersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] members in
                guard let self, state.selectedSpaceID == roomID else { return }

                state.selectedSpaceMembers = members
                    .filter { $0.membership == .join }
                    .sorted()
                    .map { RoomMemberDetails(withProxy: $0) }
            }
    }

    private func openDirectChat(with member: RoomMemberDetails) async {
        guard member.id != clientProxy.userID else { return }

        if let roomID = knownDirectRoomIDs[member.id] {
            actionsSubject.send(.selectRoom(roomID: roomID))
            return
        }

        guard pendingDirectChatUserIDs.insert(member.id).inserted else { return }
        defer { pendingDirectChatUserIDs.remove(member.id) }

        switch clientProxy.directRoomForUserID(member.id) {
        case .success(.some(let roomID)):
            knownDirectRoomIDs[member.id] = roomID
            actionsSubject.send(.selectRoom(roomID: roomID))
        case .success(.none):
            switch await clientProxy.createDirectRoom(with: member.id, expectedRoomName: member.name) {
            case .success(let roomID):
                knownDirectRoomIDs[member.id] = roomID
                actionsSubject.send(.selectRoom(roomID: roomID))
            case .failure(let error):
                MXLog.error("Failed creating direct chat from circle member: \(error)")
                showFailureIndicator()
            }
        case .failure(let error):
            MXLog.error("Failed finding direct chat from circle member: \(error)")
            showFailureIndicator()
        }
    }

    private func selectSpace(_ spaceServiceRoom: SpaceServiceRoom) async {
        switch await spaceServiceProxy.spaceRoomList(spaceID: spaceServiceRoom.id) {
        case .success(let spaceRoomListProxy):
            actionsSubject.send(.selectSpace(spaceRoomListProxy))
        case .failure(let error):
            MXLog.error("Unable to select space: \(error)")
            showFailureIndicator()
        }
    }

    // MARK: - Indicators

    private static var failureIndicatorID: String {
        "\(Self.self)-Failure"
    }

    private func showFailureIndicator() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.failureIndicatorID,
                                                              type: .toast,
                                                              title: L10n.errorUnknown,
                                                              icon: \.close))
    }
}
