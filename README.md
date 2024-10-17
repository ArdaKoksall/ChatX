# Chat Application

This is a chat application built using Flutter and Firebase. The application allows users to send and receive messages in real-time. It supports both light and dark modes.

## Features

- Real-time messaging
- User authentication
- Light and dark mode support
- Message history

## Getting Started

### Prerequisites

- Flutter SDK
- Dart
- Firebase account

### Installation

1. **Clone the repository:**

    ```sh
    git clone https://github.com/ArdaKoksall/ChatX.git
    cd your-repo-name
    ```

2. **Install dependencies:**

    ```sh
    flutter pub get
    ```

3. **Set up Firebase:**

    - Go to the [Firebase Console](https://console.firebase.google.com/).
    - Create a new project.
    - Add an Android app to your project.
    - Register your app with the package name (e.g., `com.example.chatapp`).
    - Download the `google-services.json` file and place it in the `android/app` directory.
    - Add an iOS app to your project.
    - Download the `GoogleService-Info.plist` file and place it in the `ios/Runner` directory.


4**Run the application:**

    ```sh
    flutter run
    ```

## Project Structure

- `lib/`: Contains the main source code for the application.
    - `chat.dart`: Contains the logic for sending messages.
    - `chatpage.dart`: Contains the UI for the chat page.
    - `common.dart`: Contains common utility functions.
    - `firebase_options.dart`: Contains the Firebase configuration.(Not included in the repository)
    - `login.dart`: Contains the logic for user authentication.
    - `mainpage.dart`: Contains the UI and chat logic for the main page.
    - `signup.dart`: Contains the logic for user registration.

## Security

To keep your Firebase configuration secure, do not include `firebase_options.dart` in your repository. Instead, follow the steps above to set up Firebase for your project.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.
```