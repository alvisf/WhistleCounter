import XCTest
@testable import WhistleCounter

@MainActor
final class AlarmSoundStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "AlarmSoundStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func testDefaultSound_onFreshInstall_isTriTone() {
        let store = AlarmSoundStore(defaults: defaults)
        XCTAssertEqual(store.defaultSound, .triTone)
    }

    func testChangingDefaultSound_persistsAcrossReload() {
        let first = AlarmSoundStore(defaults: defaults)
        first.defaultSound = .bell
        let reloaded = AlarmSoundStore(defaults: defaults)
        XCTAssertEqual(reloaded.defaultSound, .bell)
    }

    func testLoading_withUnknownRawValue_fallsBackToDefault() {
        defaults.set("no-such-sound", forKey: "alarm.defaultSound")
        let store = AlarmSoundStore(defaults: defaults)
        XCTAssertEqual(store.defaultSound, .triTone)
    }
}
