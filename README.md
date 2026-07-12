# Saidee App

**Saidee** is a modern mobile application built with Flutter that serves as a comprehensive platform for community and social support. It connects individuals in need with helpers, facilitates mutual aid, and provides tools for managing community resources and events.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-000000?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FF422C?style=for-the-badge&logo=firebase&logoColor=white)

## 🚀 Key Features

- **User Management**:
  - Secure authentication (Email/Password, Google Sign-In).
  - Role-based access control (User, Helper, Admin).
  - Detailed user profiles with custom roles.

- **Request Management**:
  - Users can create detailed requests for help (e.g., "Need a ride to the hospital", "Help with groceries").
  - Categorization and tagging for easy filtering.
  - Status tracking (Open, In Progress, Completed).

- **Helper System**:
  - Helpers can browse and accept requests.
  - Rating and review system to build trust.
  - Helper profiles showcasing skills and availability.

- **Community Features**:
  - **Bulletin Board**: Post announcements and updates visible to the community.
  - **Events Management**: Create and RSVP to community events.

- **Admin Panel**:
  - Comprehensive dashboard for managing users, requests, and content.
  - User management and role assignment.
  - Request moderation and monitoring.

## 🛠️ Getting Started

### Prerequisites
- Flutter SDK (stable channel) - [Download Flutter](https://flutter.dev/get-started/install)
- A Firebase Project with Firestore and Authentication enabled.

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd saidee_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables**:
   - Copy `.env.example` to a new file named `.env`:
     ```bash
     cp .env.example .env
     ```
   - Open `.env` and fill in your API keys (e.g., Google Maps, SlipOK, and Xendit).

4. **Configure Firebase**:
   - Create a `lib/firebase_options.dart` file by running:
     ```bash
     flutterfire configure --project=<your-project-id>
     ```
   - Alternatively, copy the configuration from the Firebase Console.

5. **Run the app**:
   ```bash
   flutter run
   ```

## 📂 Project Structure

```
saidee_app/
├── lib/
│   ├── core/                # Core services and utilities (Networking, Helpers)
│   ├── features/            # Feature-specific modules
│   │   ├── auth/            # Authentication flows
│   │   ├── home/            # Home screen and navigation
│   │   ├── requests/        # Request management
│   │   └── user/            # User profiles and settings
│   ├── models/              # Data models (Request, User, etc.)
│   ├── services/            # Backend services (Firebase interactions)
│   └── main.dart            # App entry point
└── test/                    # Unit and widget tests
```

## 🔌 Backend Services

This application uses **Firebase** for backend services:
- **Firestore**: Database for storing user data, requests, and community posts.
- **Firebase Authentication**: For secure user sign-in.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👋 Contributing

Contributions are welcome! Please read our [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests.

## 🤝 Team & Credits

Built with ❤️ by the Saidee Development Team.


