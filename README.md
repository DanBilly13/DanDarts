# DanDarts 🎯

A Swift-based iOS app for casual dart players who want to focus on the fun, not the math.

## Features

- **7 Game Modes**: 301, 501, Halve-It, Knockout, Sudden Death, Cricket, Killer
- **Smart Scoring**: Automatic score tracking and checkout calculations
- **Social Play**: Connect with friends, track head-to-head stats
- **Pre-Game Hype**: Boxing match style excitement before games
- **Match History**: Filter and review past games
- **Sound Effects**: Immersive audio with toggle controls

## Technical Stack

- **Platform**: iOS 17+
- **Framework**: SwiftUI
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **Architecture**: MVVM-Light
- **Storage**: Local-first with cloud sync

## Getting Started

1. Clone the repository
2. Open `DanDart.xcodeproj` in Xcode
3. Build and run on iOS Simulator or device

## Project Structure

```
DanDart/
├── Views/          # SwiftUI Views
├── ViewModels/     # MVVM ViewModels  
├── Models/         # Data models
├── Services/       # API services, managers
├── Utilities/      # Helpers, extensions
└── Resources/      # Assets, sounds, images
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## License

Private project - All rights reserved.
