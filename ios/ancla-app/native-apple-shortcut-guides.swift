import Foundation

struct NativeAppleShortcutGuide: Identifiable, Equatable {
  let id: String
  let title: String
  let apps: String
  let summary: String
  let steps: [String]
}

enum NativeAppleShortcutGuides {
  static let guides: [NativeAppleShortcutGuide] = [
    NativeAppleShortcutGuide(
      id: "safari-settings",
      title: "Safari and Settings",
      apps: "Safari, Settings",
      summary: "Use a personal automation that opens Ancla the moment Safari or Settings launches.",
      steps: [
        "Open Shortcuts and create a new Personal Automation.",
        "Choose App, set Is Opened, and enable Run Immediately.",
        "Select Safari or Settings as the trigger app.",
        "Add an Open App action that launches Ancla.",
      ]
    ),
    NativeAppleShortcutGuide(
      id: "messages-mail",
      title: "Messages and Mail",
      apps: "Messages, Mail",
      summary: "Bounce communication apps back into Ancla while a strict session is active.",
      steps: [
        "Duplicate the same Personal Automation flow for Messages or Mail.",
        "Keep the trigger on Is Opened so the redirect happens instantly.",
        "Use Open App -> Ancla as the only action.",
        "Test each automation once before relying on it.",
      ]
    ),
    NativeAppleShortcutGuide(
      id: "phone-calendar",
      title: "Phone and Calendar",
      apps: "Phone, Calendar",
      summary: "Cover the common Apple defaults that are easy to reach from habit.",
      steps: [
        "Create one automation per app so each shortcut stays obvious to audit.",
        "Set the app trigger to Is Opened with Run Immediately.",
        "Send the action straight into Ancla with Open App.",
        "Use these only for sessions where the extra friction is worth it.",
      ]
    ),
  ]
}
