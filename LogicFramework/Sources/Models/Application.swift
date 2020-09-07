import Foundation

/// `Application` is a data structure used to represent
/// installed applications. It includes bundle identifier,
/// name and path which is enough to determine uniqueness
/// if multiple instance should be installed on a system.
///
/// `Application` is used to launch applications and as a
/// part of `Group` rules.
public struct Application: Codable, Hashable {
  public let bundleIdentifier: String
  public let name: String
  public let path: String
}