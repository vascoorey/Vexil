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

/// These tests read values the same way the flag controls do: through
/// the manager, falling back to the flag's default value.
///
@available(OSX 11.0, iOS 13.0, watchOS 7.0, tvOS 13.0, *)
final class FlagValueManagerTests: XCTestCase {

    // MARK: - Fixtures

    private var first: FlagValueDictionary!
    private var second: FlagValueDictionary!
    private var pole: FlagPole<TestFlags>!
    private var manager: FlagValueManager<TestFlags>!

    override func setUp() {
        super.setUp()
        first = FlagValueDictionary()
        second = FlagValueDictionary()
        pole = FlagPole(hoist: TestFlags.self, sources: [ first, second ])
        manager = FlagValueManager(flagPole: pole, source: first)
    }

    private func boolean() -> Bool? {
        let flag = pole.$boolean
        return manager.boxedValue(key: flag.key, type: Bool.self) ?? flag.defaultValue.unwrappedBoxedValue()
    }

    private func string() -> String {
        let flag = pole.$string
        return manager.flagValue(key: flag.key) ?? flag.defaultValue
    }

    private func enumeration() -> TestEnum {
        let flag = pole.$enumeration
        return manager.flagValue(key: flag.key) ?? flag.defaultValue
    }

    private func optionalEnumeration() -> TestEnum? {
        let flag = pole.$optionalEnumeration
        let value: TestEnum?? = manager.flagValue(key: flag.key)
        return value ?? flag.defaultValue
    }


    // MARK: - Default Values

    func testReadsDefaultValueWhenNoSourceHasValue() {
        XCTAssertEqual(boolean(), false)
        XCTAssertEqual(string(), "default")
        XCTAssertEqual(enumeration(), .one)
        XCTAssertEqual(optionalEnumeration(), .one)
    }


    // MARK: - Source Hierarchy

    func testReadsValueFromFirstSource() throws {
        try first.setFlagValue(true, key: pole.$boolean.key)
        try first.setFlagValue("first", key: pole.$string.key)
        try first.setFlagValue(TestEnum.two, key: pole.$enumeration.key)

        XCTAssertEqual(boolean(), true)
        XCTAssertEqual(string(), "first")
        XCTAssertEqual(enumeration(), .two)
    }

    func testFirstSourceTakesPriorityOverSecond() throws {
        try first.setFlagValue("first", key: pole.$string.key)
        try second.setFlagValue("second", key: pole.$string.key)

        XCTAssertEqual(string(), "first")
    }

    func testReadsValueFromSecondSourceWhenFirstHasNone() throws {
        try second.setFlagValue(true, key: pole.$boolean.key)
        try second.setFlagValue("second", key: pole.$string.key)
        try second.setFlagValue(TestEnum.three, key: pole.$enumeration.key)

        XCTAssertEqual(boolean(), true)
        XCTAssertEqual(string(), "second")
        XCTAssertEqual(enumeration(), .three)
    }

    func testReadsValueFromInsertedSnapshot() {
        let snapshot = pole.emptySnapshot()
        snapshot.string = "snapshot"
        pole.insert(snapshot: snapshot, at: 0)

        XCTAssertEqual(string(), "snapshot")
    }

    func testReadsCurrentValueAfterSourceChanges() throws {
        try first.setFlagValue("before", key: pole.$string.key)
        XCTAssertEqual(string(), "before")

        try first.setFlagValue("after", key: pole.$string.key)
        XCTAssertEqual(string(), "after")

        try first.setFlagValue(String?.none, key: pole.$string.key)        // swiftlint:disable:this syntactic_sugar
        XCTAssertEqual(string(), "default")
    }


    // MARK: - Optional Values

    func testReadsOptionalValueFromSource() throws {
        try first.setFlagValue(TestEnum?.some(.two), key: pole.$optionalEnumeration.key)

        XCTAssertEqual(optionalEnumeration(), .two)
    }

    func testExplicitNilTakesPriorityOverLowerSource() throws {
        try first.setFlagValue(TestEnum??.some(nil), key: pole.$optionalEnumeration.key)
        try second.setFlagValue(TestEnum?.some(.three), key: pole.$optionalEnumeration.key)

        XCTAssertNil(optionalEnumeration())
    }

    func testExplicitNilTakesPriorityOverDefaultValue() throws {
        try first.setFlagValue(TestEnum??.some(nil), key: pole.$optionalEnumeration.key)

        XCTAssertNil(optionalEnumeration())
    }

    func testExplicitNilInUserDefaultsTakesPriorityOverLowerSource() throws {
        let suiteName = "VexillographerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pole = FlagPole(hoist: TestFlags.self, sources: [ defaults, second ])
        let manager = FlagValueManager(flagPole: pole, source: defaults)
        let flag = pole.$optionalEnumeration

        try defaults.setFlagValue(TestEnum??.some(nil), key: flag.key)
        try second.setFlagValue(TestEnum?.some(.three), key: flag.key)

        let value: TestEnum?? = manager.flagValue(key: flag.key)
        XCTAssertNil(value ?? flag.defaultValue)
    }

}


// MARK: - Fixtures

private enum TestEnum: String, FlagValue, CaseIterable {
    case one
    case two
    case three
}

private struct TestFlags: FlagContainer {

    @Flag(default: false, description: "A boolean flag")
    var boolean: Bool

    @Flag(default: "default", description: "A string flag")
    var string: String

    @Flag(default: .one, description: "An enum flag")
    var enumeration: TestEnum

    @Flag(default: .one, description: "An optional enum flag")
    var optionalEnumeration: TestEnum?

}

#endif
