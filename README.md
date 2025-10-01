# EPUB to Audiobook Converter

A modern native macOS application that converts DRM-free EPUB files into high-quality M4A audiobook files using Kokoro Neural TTS with ML voices.

## Features

- **Single-Screen UI**: Clean, modern SwiftUI interface
- **Advanced Text Normalization**: Multiple modes for text processing
- **Comprehensive EPUB Parsing**: Supports EPUB2/3 with DRM detection
- **High-Quality TTS**: Uses Kokoro Neural TTS for natural-sounding voices
- **Chapter-Based Output**: Generates separate M4A files for each chapter
- **Privacy-First**: 100% local processing, no data leaves your device
- **Protocol-Oriented Design**: Extensible service architecture
- **Comprehensive Testing**: Full test coverage for normalization logic

## Architecture

The app follows a protocol-oriented design with clear separation of concerns:

- **Models**: Data structures for EPUB content and app state
- **Services**: Protocol-based services for parsing, normalization, and TTS
- **Views**: SwiftUI views for the user interface
- **Utilities**: Helper functions and extensions

## Key Components

### Services
- `EPUPParserService`: Handles EPUB file parsing and DRM detection
- `TextNormalizationService`: Advanced text processing with multiple modes
- `TTSService`: Integration with Kokoro Neural TTS
- `AudioExportService`: M4A file generation and chapter management

### Text Normalization Modes
- Newline handling (preserve, convert to spaces, remove)
- Footnote removal (automatic detection and removal)
- Regex find/replace (custom text transformations)
- Chapter title detection and formatting

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Kokoro Neural TTS SDK
- Swift 5.9+

## Installation

1. Clone the repository
2. Install Kokoro Neural TTS SDK
3. Open in Xcode and build

## Usage

1. Launch the app
2. Drag and drop an EPUB file onto the interface
3. Configure text normalization settings
4. Select voice and quality options
5. Click "Convert" to generate audiobook files

## Privacy

This application processes all files locally on your device. No EPUB content, generated audio, or any other data is transmitted to external servers.