import Testing
import EFData

// EF_DATA_SOURCE = mock | snapshot | backoffice (build setting or launch argument).

@Suite struct DataSourceKindTests {
    @Test(arguments: zip(["mock", "snapshot", "backoffice"], [DataSourceKind.mock, .snapshot, .backoffice]))
    func aKnownValueSelectsItsSource(value: String, kind: DataSourceKind) {
        #expect(DataSourceKind(rawValue: value) == kind)
    }

    @Test(arguments: ["", "Mock", "MOCK", " mock", "mock ", "back-office", "remote", "$(EF_DATA_SOURCE)"])
    func anyOtherValueIsRejected(value: String) {
        #expect(DataSourceKind(rawValue: value) == nil)
    }
}
