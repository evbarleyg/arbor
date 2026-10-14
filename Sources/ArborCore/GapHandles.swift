extension GapHandles {
  /// A value nobody defined (a typo in settings.json) means the default. In any case of letters.
  public init(setting: String) { self = GapHandles(rawValue: setting.lowercased()) ?? .shown }
}
