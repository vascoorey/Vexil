//===----------------------------------------------------------------------===//
//
// This source file is part of the Vexil open source project
//
// Copyright (c) 2023 Unsigned Apps and the open source contributors.
// Licensed under the MIT license
//
// See LICENSE for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import Vexil
@testable import Vexillographer
import XCTest

@available(OSX 11.0, iOS 13.0, watchOS 7.0, tvOS 13.0, *)
final class UnfurledFlagGroupTests: XCTestCase {

    // MARK: - Fixtures

    private var pole: FlagPole<TestFlags>!
    private var manager: FlagValueManager<TestFlags>!

    override func setUp() {
        super.setUp()
        let source = FlagValueDictionary()
        pole = FlagPole(hoist: TestFlags.self, sources: [ source ])
        manager = FlagValueManager(flagPole: pole, source: source)
    }

    private func unfurl<Group>(_ group: FlagGroup<Group>) -> UnfurledFlagGroup<Group, TestFlags> where Group: FlagContainer {
        return UnfurledFlagGroup(name: "Group", group: group, manager: manager)
    }

    private func names(_ items: [UnfurledFlagItem]?) -> [String]? {
        return items?.map(\.info.name)
    }


    // MARK: - Root Items

    func testRootOmitsHiddenAndUneditableItems() {
        XCTAssertEqual(
            names(manager.allItems()),
            [ "Top Level Flag", "Editable", "Mixed", "Outer", "Section" ]
        )
    }


    // MARK: - Editable Groups

    func testGroupWithEditableFlagsIsEditable() {
        let group = unfurl(pole.editableWrapper)

        XCTAssertTrue(group.isEditable)
        XCTAssertEqual(names(group.allItems()), [ "Boolean", "String", "Enumeration", "Optional Enumeration" ])
        XCTAssertNotNil(pole.editableWrapper.unfurl(label: "editable", manager: manager))
    }

    func testGroupOmitsHiddenAndUneditableChildren() {
        let group = unfurl(pole.mixedWrapper)

        XCTAssertTrue(group.isEditable)
        XCTAssertEqual(names(group.allItems()), [ "Last" ])
    }


    // MARK: - Uneditable Groups

    func testGroupWithOnlyUneditableFlagsIsNotEditable() {
        let group = unfurl(pole.uneditableWrapper)

        XCTAssertFalse(group.isEditable)
        XCTAssertEqual(names(group.allItems()), [])
        XCTAssertNil(pole.uneditableWrapper.unfurl(label: "uneditable", manager: manager))
    }

    func testGroupWithOnlyHiddenFlagsIsNotEditable() {
        let group = unfurl(pole.onlyHiddenWrapper)

        XCTAssertFalse(group.isEditable)
        XCTAssertEqual(names(group.allItems()), [])
        XCTAssertNil(pole.onlyHiddenWrapper.unfurl(label: "onlyHidden", manager: manager))
    }

    func testGroupContainingOnlyEmptyGroupsIsNotEditable() {
        let group = unfurl(pole.hollowWrapper)

        XCTAssertFalse(group.isEditable)
        XCTAssertEqual(names(group.allItems()), [])
        XCTAssertNil(pole.hollowWrapper.unfurl(label: "hollow", manager: manager))
    }

    func testHiddenGroupDoesNotUnfurl() {
        XCTAssertNil(pole.hiddenGroupWrapper.unfurl(label: "hiddenGroup", manager: manager))
    }


    // MARK: - Nested Groups

    func testNestedGroupsAreEditableWhenDeepestGroupIs() {
        let outer = unfurl(pole.outerWrapper)
        XCTAssertTrue(outer.isEditable)
        XCTAssertEqual(names(outer.allItems()), [ "Middle" ])

        let middle = unfurl(pole.outer.middleWrapper)
        XCTAssertTrue(middle.isEditable)
        XCTAssertEqual(names(middle.allItems()), [ "Inner" ])

        let inner = unfurl(pole.outer.middle.innerWrapper)
        XCTAssertTrue(inner.isEditable)
        XCTAssertEqual(names(inner.allItems()), [ "Deep Flag" ])
    }


    // MARK: - Child Links

    func testChildLinksContainOnlyNavigationGroups() {
        let group = unfurl(pole.sectionWrapper)

        XCTAssertEqual(names(group.allItems()), [ "Flag", "Linked", "Inline" ])
        XCTAssertEqual(names(group.childLinks), [ "Linked" ])
    }

    func testChildLinksAreNilWithoutNavigationGroups() {
        XCTAssertNil(unfurl(pole.editableWrapper).childLinks)
        XCTAssertNil(unfurl(pole.uneditableWrapper).childLinks)
    }

}


// MARK: - Fixtures

private enum TestEnum: String, FlagValue, CaseIterable {
    case one
    case two
}

private struct TestFlags: FlagContainer {

    @Flag(default: false, description: "A top level flag")
    var topLevelFlag: Bool

    @Flag(default: Data(), description: "A top level flag that cannot be edited")
    var topLevelData: Data

    @FlagGroup(description: "Flags of every editable kind")
    var editable: EditableFlags

    var editableWrapper: FlagGroup<EditableFlags> {
        return _editable
    }

    @FlagGroup(description: "Flags that cannot be edited")
    var uneditable: UneditableFlags

    var uneditableWrapper: FlagGroup<UneditableFlags> {
        return _uneditable
    }

    @FlagGroup(description: "Flags that are hidden")
    var onlyHidden: HiddenFlags

    var onlyHiddenWrapper: FlagGroup<HiddenFlags> {
        return _onlyHidden
    }

    @FlagGroup(description: "Hidden, uneditable and editable flags")
    var mixed: MixedFlags

    var mixedWrapper: FlagGroup<MixedFlags> {
        return _mixed
    }

    @FlagGroup(description: "Groups that contain nothing editable")
    var hollow: HollowFlags

    var hollowWrapper: FlagGroup<HollowFlags> {
        return _hollow
    }

    @FlagGroup(description: .hidden)
    var hiddenGroup: EditableFlags

    var hiddenGroupWrapper: FlagGroup<EditableFlags> {
        return _hiddenGroup
    }

    @FlagGroup(description: "Three levels of nesting")
    var outer: OuterFlags

    var outerWrapper: FlagGroup<OuterFlags> {
        return _outer
    }

    @FlagGroup(description: "Navigation and section subgroups", display: .section)
    var section: SectionFlags

    var sectionWrapper: FlagGroup<SectionFlags> {
        return _section
    }

}

private struct EditableFlags: FlagContainer {

    @Flag(default: false, description: "A boolean flag")
    var boolean: Bool

    @Flag(default: "default", description: "A string flag")
    var string: String

    @Flag(default: .one, description: "An enum flag")
    var enumeration: TestEnum

    @Flag(default: .one, description: "An optional enum flag")
    var optionalEnumeration: TestEnum?

}

private struct UneditableFlags: FlagContainer {

    @Flag(default: Data(), description: "A data flag")
    var data: Data

    @Flag(default: [:], description: "A dictionary flag")
    var dictionary: [String: String]

}

private struct HiddenFlags: FlagContainer {

    @Flag(default: false, description: .hidden)
    var boolean: Bool

}

private struct MixedFlags: FlagContainer {

    @Flag(default: false, description: .hidden)
    var hidden: Bool

    @Flag(default: Data(), description: "A data flag")
    var data: Data

    @FlagGroup(description: "A group with nothing editable")
    var uneditable: UneditableFlags

    @Flag(default: false, description: "The only editable flag")
    var last: Bool

}

private struct HollowFlags: FlagContainer {

    @FlagGroup(description: "A group with nothing editable")
    var uneditable: UneditableFlags

    @FlagGroup(description: "A group with nothing visible")
    var hidden: HiddenFlags

}

private struct OuterFlags: FlagContainer {

    @FlagGroup(description: "The middle group")
    var middle: MiddleFlags

    var middleWrapper: FlagGroup<MiddleFlags> {
        return _middle
    }

}

private struct MiddleFlags: FlagContainer {

    @FlagGroup(description: "The inner group")
    var inner: InnerFlags

    var innerWrapper: FlagGroup<InnerFlags> {
        return _inner
    }

}

private struct InnerFlags: FlagContainer {

    @Flag(default: false, description: "A deeply nested flag")
    var deepFlag: Bool

}

private struct SectionFlags: FlagContainer {

    @Flag(default: false, description: "A flag")
    var flag: Bool

    @FlagGroup(description: "A navigation subgroup")
    var linked: EditableFlags

    @FlagGroup(description: "A section subgroup", display: .section)
    var inline: EditableFlags

}

#endif
