//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct SpacesScreen: View {
    @Bindable var context: SpacesScreenViewModel.Context

    var body: some View {
        mainContent
            .navigationTitle("Circles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toolbarBackground(SilentBrand.blue, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(SilentBrand.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var mainContent: some View {
        if context.viewState.topLevelSpaces.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    circlesSelector

                    if let selectedSpace = context.viewState.selectedSpace {
                        circleHeader(selectedSpace)
                        contactsSection
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        FullscreenDialog(horizontalPadding: 24) {
            TitleAndIcon(title: "No circles yet",
                         icon: \.spaceSolid,
                         iconStyle: .defaultSolid)
        } bottomContent: {
            Button("Create circle") {
                context.send(viewAction: .createSpace)
            }
            .buttonStyle(.compound(.primary))
        }
    }

    private var circlesSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                CircleSelectorItem(label: "New", isSelected: false) {
                    context.send(viewAction: .createSpace)
                } avatar: {
                    ZStack {
                        Circle()
                            .fill(SilentBrand.blue.opacity(0.10))
                        CompoundIcon(\.plus, size: .medium, relativeTo: .body)
                            .foregroundStyle(SilentBrand.blue)
                    }
                    .frame(width: 44, height: 44)
                }

                ForEach(context.viewState.topLevelSpaces, id: \.id) { space in
                    CircleSelectorItem(label: space.name,
                                       isSelected: context.viewState.selectedSpaceID == space.id) {
                        context.send(viewAction: .selectSpace(space))
                    } avatar: {
                        LoadableAvatarImage(url: space.avatarURL,
                                            name: space.name,
                                            contentID: space.id,
                                            shape: .circle,
                                            avatarSize: .user(on: .spaces),
                                            mediaProvider: context.mediaProvider)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.compound.bgCanvasDefault)
    }

    private func circleHeader(_ selectedSpace: SpaceServiceRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
                .frame(height: 64)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSpace.name)
                        .font(.compound.headingMDBold)
                        .foregroundStyle(.compound.textPrimary)
                        .lineLimit(2)

                    Text(L10n.commonMemberCount(selectedSpace.joinedMembersCount))
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                }

                Spacer()

                Button {
                    context.send(viewAction: .openSpaceDetails(selectedSpace))
                } label: {
                    CompoundIcon(\.edit, size: .medium, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(SilentBrand.dark, in: RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Edit circle")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [
                Color(red: 0.91, green: 0.95, blue: 1.00),
                Color(red: 0.96, green: 0.92, blue: 1.00),
                SilentBrand.background
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var contactsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Contacts")
                    .font(.compound.bodyLGSemibold)
                    .foregroundStyle(SilentBrand.blue)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            searchPlaceholder
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            HStack {
                Text("Show: All")
                    .font(.compound.bodySM)
                    .foregroundStyle(.compound.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            memberList
        }
        .background(Color.compound.bgCanvasDefault)
    }

    private var searchPlaceholder: some View {
        HStack(spacing: 8) {
            CompoundIcon(\.search, size: .small, relativeTo: .body)
                .foregroundStyle(.compound.iconSecondary)

            Text("Search contacts...")
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.compound.bgCanvasDefault, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.compound.borderInteractiveSecondary, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var memberList: some View {
        if let selectedSpaceMembers = context.viewState.selectedSpaceMembers {
            if selectedSpaceMembers.isEmpty {
                CircleMessageRow(message: "No contacts found")
            } else {
                ForEach(selectedSpaceMembers) { member in
                    CircleMemberRow(member: member,
                                    mediaProvider: context.mediaProvider) {
                        context.send(viewAction: .selectMember(member))
                    }
                    if selectedSpaceMembers.last != member {
                        Rectangle()
                            .fill(Color.compound.borderDisabled)
                            .frame(height: 1 / UIScreen.main.scale)
                            .padding(.leading, 68)
                    }
                }
            }
        } else {
            CircleMessageRow(message: "Loading contacts...")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                context.send(viewAction: .showSettings)
            } label: {
                LoadableAvatarImage(url: context.viewState.userAvatarURL,
                                    name: context.viewState.userDisplayName,
                                    contentID: context.viewState.userID,
                                    avatarSize: .user(on: .spaces),
                                    mediaProvider: context.mediaProvider)
                    .frame(width: 32, height: 32)
                    .accessibilityIdentifier(A11yIdentifiers.homeScreen.userAvatar)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.commonSettings)
        }

        ToolbarItem(placement: .principal) {
            Text("Circles")
                .font(.compound.headingSMSemibold)
                .foregroundStyle(.white)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                context.send(viewAction: .createSpace)
            } label: {
                CompoundIcon(\.plus)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Create circle")
        }
    }
}

private struct CircleSelectorItem<Avatar: View>: View {
    let label: String
    let isSelected: Bool
    let onClick: () -> Void
    @ViewBuilder let avatar: () -> Avatar

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? SilentBrand.blue : Color.compound.borderDisabled,
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: 48, height: 48)

                    avatar()
                }

                Text(label)
                    .font(.compound.bodyXS)
                    .foregroundStyle(.compound.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 58)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 58)
    }
}

private struct CircleMemberRow: View {
    let member: RoomMemberDetails
    let mediaProvider: MediaProviderProtocol?
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                LoadableAvatarImage(url: member.avatarURL,
                                    name: member.name,
                                    contentID: member.id,
                                    avatarSize: .user(on: .spaces),
                                    mediaProvider: mediaProvider)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name ?? member.id)
                        .font(.compound.bodyMDSemibold)
                        .foregroundStyle(.compound.textPrimary)
                        .lineLimit(1)

                    Text(member.id)
                        .font(.compound.bodySM)
                        .foregroundStyle(.compound.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CircleMessageRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.compound.bodyMD)
            .foregroundStyle(.compound.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
    }
}

private enum SilentBrand {
    static let blue = Color(red: 21.0 / 255.0, green: 85.0 / 255.0, blue: 224.0 / 255.0)
    static let dark = Color(red: 30.0 / 255.0, green: 30.0 / 255.0, blue: 30.0 / 255.0)
    static let background = Color(red: 238.0 / 255.0, green: 239.0 / 255.0, blue: 242.0 / 255.0)
}

// MARK: - Previews

struct SpacesScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    static let emptyViewModel = makeViewModel(isEmpty: true)

    static var previews: some View {
        ElementNavigationStack {
            SpacesScreen(context: viewModel.context)
        }

        ElementNavigationStack {
            SpacesScreen(context: emptyViewModel.context)
        }
        .previewDisplayName("Empty")
    }

    static func makeViewModel(isEmpty: Bool = false) -> SpacesScreenViewModel {
        let appSettings = AppSettings.volatile()

        let clientProxy = ClientProxyMock(.init())
        clientProxy.spaceService = SpaceServiceProxyMock(.init(topLevelSpaces: isEmpty ? [] : .mockJoinedSpaces))

        return SpacesScreenViewModel(userSession: UserSessionMock(.init(clientProxy: clientProxy)),
                                     selectedSpacePublisher: .init(nil),
                                     appSettings: appSettings,
                                     userIndicatorController: UserIndicatorControllerMock())
    }
}
