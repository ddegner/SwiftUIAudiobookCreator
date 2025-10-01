# Setup Instructions

## Prerequisites

1. **macOS Development Environment**
   - macOS 13.0 or later
   - Xcode 15.0 or later
   - Swift 5.9 or later

2. **Kokoro Neural TTS SDK**
   - Download from official Kokoro website
   - Follow their installation guide
   - Ensure proper licensing and API key setup

3. **Development Tools**
   - Git for version control
   - CocoaPods or Swift Package Manager (if needed for dependencies)

## Step-by-Step Setup

### 1. Create New Xcode Project

1. Open Xcode
2. Select "Create a new Xcode project"
3. Choose "macOS" → "App"
4. Configure project:
   - Product Name: `EPUBAudiobookConverter`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Use Core Data: `No`
   - Include Tests: `Yes`

### 2. Project Configuration

1. **Deployment Target**: Set to macOS 13.0
2. **Bundle Identifier**: Choose appropriate identifier
3. **Code Signing**: Configure for your Apple Developer account

### 3. Create Directory Structure

Create the following folder structure in your Xcode project:

```
EPUBAudiobookConverter/
├── App/
├── Models/
├── Services/
│   └── Protocols/
├── Views/
│   └── Components/
├── Utilities/
│   ├── EPUBParser/
│   ├── TextProcessing/
│   └── Extensions/
└── Resources/
```

### 4. Add Kokoro TTS Framework

1. Download Kokoro Neural TTS SDK
2. Add framework to your project:
   - Drag framework into Xcode project
   - Ensure "Copy items if needed" is checked
   - Add to target
3. Configure framework search paths if needed

### 5. Configure Build Settings

Add the following build settings:

- **Other Linker Flags**: Add `-framework KokoroTTS` (adjust name as needed)
- **Framework Search Paths**: Add path to Kokoro framework
- **Header Search Paths**: Add path to Kokoro headers

### 6. Create Test Targets

Ensure you have:
- Unit test target for business logic
- UI test target for interface testing

### 7. Add Required Permissions

In `Info.plist`, add:
```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to save generated audiobook files.</string>
```

### 8. Initial Build

1. Clean build folder (⌘+Shift+K)
2. Build project (⌘+B)
3. Resolve any framework linking issues

## Next Steps

After setup completion:
1. Follow the implementation guides for each component
2. Start with the protocol definitions
3. Implement services in dependency order
4. Build UI components
5. Add comprehensive tests

## Troubleshooting

### Common Issues

1. **Framework Not Found**
   - Verify framework is properly added to project
   - Check framework search paths
   - Ensure correct deployment target

2. **Code Signing Issues**
   - Configure proper team and bundle identifier
   - Check provisioning profiles

3. **Build Errors**
   - Clean build folder
   - Check Swift version compatibility
   - Verify all dependencies are properly linked

### Getting Help

- Check Kokoro TTS documentation for SDK-specific issues
- Review Apple's SwiftUI and macOS development guides
- Consult project documentation in the `/Documentation` folder