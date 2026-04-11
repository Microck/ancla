import Foundation

struct NativeAppleShortcutGuide: Identifiable, Equatable {
  let id: String
  let title: String
  let summary: String
  let steps: [String]
  let suggestedApps: [String]
}

enum NativeAppleShortcutGuides {
  static let guide = NativeAppleShortcutGuide(
    id: "all-blocked-apps",
    title: "Build one redirect automation",
    summary: "Create one Shortcuts personal automation that watches every app you want Ancla to gate. The automation checks Ancla first and only opens it while a block is active.",
    steps: [
      "Open Shortcuts and create a new Personal Automation.",
      "Choose App, set Is Opened, and enable Run Immediately.",
      "Select every app you want blocked by Ancla, then confirm the trigger list.",
      "Add the Ancla action Get Block Status.",
      "Add an If step. If the result is true, run Open App -> Ancla. Otherwise do nothing.",
      "Test the automation once with a live block and once with no block active.",
      "When you decide to gate another app later, edit this same automation and add it to the trigger list.",
    ],
    suggestedApps: [
      "Safari",
      "Settings",
      "Messages",
      "Mail",
      "Phone",
      "Calendar",
    ]
  )
}
