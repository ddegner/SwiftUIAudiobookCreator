# Quick Start Guide

## Getting Started with EPUB to Audiobook Converter

This guide will help you quickly set up and start using the EPUB to Audiobook converter app.

## Prerequisites

Before you begin, ensure you have:

- **macOS 13.0 or later**
- **Xcode 15.0 or later**
- **Kokoro Neural TTS SDK** (download from official website)
- **Apple Developer Account** (for code signing)

## Step 1: Project Setup

### 1.1 Create New Xcode Project
1. Open Xcode
2. Select "Create a new Xcode project"
3. Choose "macOS" → "App"
4. Configure:
   - Product Name: `EPUBAudiobookConverter`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Use Core Data: `No`
   - Include Tests: `Yes`

### 1.2 Configure Project Settings
1. Set deployment target to macOS 13.0
2. Configure bundle identifier
3. Set up code signing for your Apple Developer account

## Step 2: Add Kokoro TTS Framework

### 2.1 Download and Add Framework
1. Download Kokoro Neural TTS SDK
2. Drag the framework into your Xcode project
3. Ensure "Copy items if needed" is checked
4. Add to your app target

### 2.2 Configure Build Settings
Add these build settings:
- **Other Linker Flags**: `-framework KokoroTTS`
- **Framework Search Paths**: Path to Kokoro framework
- **Header Search Paths**: Path to Kokoro headers

## Step 3: Implement Core Components

### 3.1 Create Directory Structure
Create these folders in your Xcode project:
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

### 3.2 Add Core Files
Copy the implementation files from the provided documentation:
- **Models**: `EPUBBook.swift`, `NormalizationSettings.swift`, etc.
- **Services**: `EPUPParserService.swift`, `TextNormalizationService.swift`, etc.
- **Views**: `ContentView.swift`, `SidebarView.swift`, etc.
- **Utilities**: Helper classes and extensions

## Step 4: Configure Permissions

### 4.1 Add Info.plist Entries
Add these keys to your `Info.plist`:
```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to save generated audiobook files.</string>
```

## Step 5: Build and Test

### 5.1 Initial Build
1. Clean build folder (⌘+Shift+K)
2. Build project (⌘+B)
3. Resolve any framework linking issues

### 5.2 Run Tests
1. Run unit tests (⌘+U)
2. Verify all tests pass
3. Check test coverage

## Step 6: First Run

### 6.1 Launch App
1. Run the app (⌘+R)
2. Verify the interface loads correctly
3. Check that voice settings are populated

### 6.2 Test with Sample EPUB
1. Find a DRM-free EPUB file
2. Drag and drop it onto the app
3. Configure settings
4. Start conversion

## Common Issues and Solutions

### Framework Not Found
**Problem**: Build errors about missing Kokoro framework
**Solution**: 
- Verify framework is properly added to project
- Check framework search paths in build settings
- Ensure correct deployment target

### Code Signing Issues
**Problem**: App won't run due to code signing
**Solution**:
- Configure proper team in project settings
- Check bundle identifier is unique
- Verify provisioning profiles

### TTS Service Unavailable
**Problem**: TTS service shows as unavailable
**Solution**:
- Verify Kokoro TTS SDK is properly installed
- Check API key configuration
- Ensure proper licensing

### EPUB Parsing Errors
**Problem**: EPUB files fail to parse
**Solution**:
- Verify file is DRM-free
- Check file format compatibility
- Review error messages for specific issues

## Next Steps

### Customization
- **Voice Settings**: Adjust speed, pitch, and volume
- **Text Processing**: Configure normalization settings
- **Output Format**: Customize audio quality and format

### Advanced Features
- **Batch Processing**: Convert multiple books
- **Custom Replacements**: Add text transformations
- **Quality Optimization**: Fine-tune audio output

### Distribution
- **App Store**: Prepare for macOS App Store
- **Direct Distribution**: Set up outside App Store distribution
- **Updates**: Implement automatic update mechanism

## Support and Resources

### Documentation
- Review all implementation guides
- Check API documentation
- Consult testing guides

### Troubleshooting
- Check error logs in Xcode console
- Review test failures
- Consult Kokoro TTS documentation

### Community
- Join developer forums
- Share experiences and solutions
- Contribute to improvements

## Quick Reference

### Essential Files
- `ContentView.swift` - Main interface
- `EPUPParserService.swift` - EPUB processing
- `TextNormalizationService.swift` - Text processing
- `KokoroTTSService.swift` - Voice synthesis
- `AudioExportService.swift` - Audio output

### Key Settings
- **Voice**: Select from available options
- **Speed**: 0.5x to 2.0x range
- **Quality**: Standard, High, Premium
- **Normalization**: Configure text processing

### File Locations
- **Generated Audio**: Documents/Audiobooks/
- **Temporary Files**: System temp directory
- **Settings**: User defaults

This quick start guide provides the essential steps to get your EPUB to Audiobook converter up and running. For detailed implementation information, refer to the comprehensive documentation provided in the other guides.