# Flutter Application

A cross-platform mobile application built with Flutter for image annotation and visual search.

## Features

- **Image Capture**: Capture photos using the device camera or select from the gallery.
- **Geo-Tagging**: Automatically captures the device's location (latitude/longitude) when an image is selected.
- **Visual Search**: Allows users to tap on a specific object in an image to search for similar objects in the database.
- **Annotation**: Upload and annotate images with metadata.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio / Xcode (for mobile emulators or devices)

## Setup & Run

1.  Navigate to the `FlutterApp` directory:

    ```bash
    cd FlutterApp
    ```

2.  Install dependencies:

    ```bash
    flutter pub get
    ```

3.  Run the application:

    ```bash
    flutter run
    ```

    _Note: Ensure the backend services (NodeGateway) are running and accessible. You might need to adjust the API base URL in `lib/services/api_service.dart` if testing on a real device or a different emulator configuration._

## Architecture

The app uses the `http` package to communicate with the NodeGateway. It manages state locally and handles permissions for camera and location access.
