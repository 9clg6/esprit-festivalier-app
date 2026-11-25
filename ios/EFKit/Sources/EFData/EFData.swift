/// Data sources: mocks, snapshot cache and synchronisation.
public enum EFData {}

/// Which data source the app runs on (`EF_DATA_SOURCE` build setting).
public enum DataSourceKind: String, Sendable {
    case mock
    case snapshot
    case backoffice
}
