# Project Raseed

**Project Raseed**, developed by **Team Mugiwara no Ichimi** for the **Agentic AI Day Hackathon** presented by Google Cloud and powered by [Hack2skill](https://hack2skill.com) with [Fi Money](https://fi.money) as the premium partner, is a cross-platform Flutter application designed to revolutionize expense tracking and receipt management. Leveraging Google’s cutting-edge tools, including Firebase for authentication, storage, and real-time database capabilities, and Google Gemini for intelligent receipt processing, the app enables users to upload receipt images, extract structured data, interact with a chatbot for insights, and manage preferences seamlessly across Android, iOS, web, Linux, macOS, and Windows platforms. Explore the project on [GitHub](https://github.com/itzz-keerthi/mugiwara-no-ichimi).[](https://gdg.community.dev/events/details/google-gdg-bangalore-presents-agentic-ai-day-hackathon/)

## Features

- **Receipt Upload and Processing**: Upload receipt images and extract structured data (items, expense category, reimbursable items) using Google Gemini AI.
- **User Authentication**: Secure sign-in with Google Sign-In, powered by Firebase Authentication.
- **Cloud Storage**: Store receipt images in Google Firebase Storage for secure and scalable access.
- **Real-Time Data**: Manage user preferences and receipt data with Google Firestore for real-time synchronization.
- **Smart Actions**: Generate personalized suggestions based on user preferences and receipt data using Google Gemini.
- **Google Wallet Integration**: Add receipts to Google Wallet for easy access and organization.
- **Cross-Platform Support**: Run the app on Android, iOS, web, Linux, macOS, and Windows with a single codebase.
- **Chatbot Interaction**: Engage with a chatbot to query receipt data, powered by Firebase and Google Gemini.

## Hackathon Context

**Project Raseed** was developed as part of the **Agentic AI Day Hackathon 2025**, hosted by Google Developer Groups GDG Bangalore and powered by Hack2skill, with Fi Money as the premium partner. The hackathon, held on July 26, 2025, challenged participants to build the next generation of intelligent agents using Google Cloud AI Studio, Gemini, Vertex AI, and Firebase. Our solution harnesses these technologies to deliver a user-centric, AI-driven receipt management system.[](https://gdg.community.dev/events/details/google-gdg-bangalore-presents-agentic-ai-day-hackathon/)

## Prerequisites

Before setting up **Project Raseed**, ensure you have the following tools and accounts:

- **Flutter SDK**: Version 3.8.1 or higher (stable channel recommended).
- **Dart SDK**: Included with Flutter, version ^3.8.1.
- **Google Cloud Account**: Required for Firebase and Google Gemini API access.
- **Firebase Project**: Set up a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
- **Google Cloud Storage Bucket**: Configured in your Firebase project for storing receipt images.
- **Google Gemini API Key**: Obtain an API key from the [Google Cloud Console](https://console.cloud.google.com/) for receipt processing.
- **Development Environment**:
  - **Android**: Android Studio with Android SDK (API level 21 or higher).
  - **iOS**: Xcode 14.0 or higher (macOS required).
  - **Web**: Chrome or another modern browser.
  - **Linux/macOS/Windows**: Appropriate build tools (e.g., CMake for Linux/Windows, Xcode for macOS).
- **Git**: For cloning the repository.
- **IDE**: Visual Studio Code or Android Studio with Flutter and Dart plugins.

## Setup Instructions

Follow these steps to set up and run **Project Raseed** locally.

### 1. Clone the Repository

Clone the repository from [GitHub](https://github.com/itzz-keerthi/mugiwara-no-ichimi):

```bash
git clone https://github.com/itzz-keerthi/mugiwara-no-ichimi.git
cd mugiwara-no-ichimi
```

### 2. Install Dependencies

Install Flutter dependencies listed in `pubspec.yaml`:

```bash
flutter pub get
```

This will download all required packages, including `firebase_core`, `firebase_storage`, `cloud_firestore`, `google_sign_in`, and others.

### 3. Configure Firebase

1. **Create a Firebase Project**:
   - Go to the [Firebase Console](https://console.firebase.google.com/).
   - Create a new project (e.g., "Project Raseed").
   - Add apps for Android, iOS, and web as needed.

2. **Download Configuration Files**:
   - For **Android**, download `google-services.json` and place it in `receipt_manager/android/app/`.
   - For **iOS**, download `GoogleService-Info.plist` and place it in `receipt_manager/ios/Runner/`.
   - For **web**, copy the Firebase configuration (API key, project ID, etc.) and update `receipt_manager/web/index.html` with the Firebase SDK initialization.

3. **Enable Firebase Services**:
   - Enable **Firebase Authentication** with Google Sign-In in the Firebase Console.
   - Enable **Firebase Storage** for image uploads.
   - Enable **Firestore Database** for storing receipt and user preference data.
   - Configure Firestore security rules to allow authenticated access (update rules in the Firebase Console).

4. **Add Firebase Admin SDK**:
   - Download the Firebase Admin SDK credentials (`mugiwara-no-ichimi-firebase-adminsdk-fbsvc-6bf822a736.json`) from the Firebase Console.
   - Place the credentials file in `receipt_manager/backend/secrets/`.
   - Ensure the file is referenced in `backend/init.py`.

### 4. Configure Google Gemini API

1. **Obtain Gemini API Key**:
   - In the [Google Cloud Console](https://console.cloud.google.com/), create a new project or use an existing one.
   - Enable the Google Gemini API.
   - Generate an API key and set it as an environment variable in `backend/.env`:
     ```env
     GEMINI_API_KEY=your-api-key
     ```

2. **Update Backend**:
   - Ensure `backend/gemini_processor.py` references the Gemini API key via `os.getenv("GEMINI_API_KEY")`.

### 5. Configure Platform-Specific Settings

- **Android**:
  - Update `receipt_manager/android/app/build.gradle.kts` to set the `minSdkVersion` to 21 or higher.
  - Ensure the `google-services.json` file is correctly placed.

- **iOS**:
  - Open `receipt_manager/ios/Runner.xcodeproj` in Xcode.
  - Update the bundle identifier to match your Firebase app.
  - Add Google Sign-In capabilities in the Xcode project settings.

- **Web**:
  - Ensure the Firebase configuration in `receipt_manager/web/index.html` is correct.
  - Test on a modern browser like Chrome.

- **Linux/macOS/Windows**:
  - Ensure CMake is installed for Linux and Windows builds.
  - For macOS, ensure Xcode is configured with the correct signing team.

### 6. Set Up Environment Variables

Create a `.env` file in the `backend/` directory to store sensitive information:

```env
GEMINI_API_KEY=your-gemini-api-key
```

Ensure the `.env` file is included in `backend/.gitignore` to prevent it from being committed.

### 7. Run the Backend

1. Navigate to the `backend/` directory:
   ```bash
   cd backend
   ```

2. Install Python dependencies:
   ```bash
   pip install fastapi uvicorn firebase-admin google-generativeai pydantic python-dotenv
   ```

3. Start the FastAPI server:
   ```bash
   uvicorn main:app --reload
   ```

The backend will run on `http://localhost:8000`. Test the `/ping` endpoint to ensure it’s working:

```bash
curl http://localhost:8000/ping
```

### 8. Run the Flutter App

1. Return to the project root:
   ```bash
   cd ..
   ```

2. Run the Flutter app for your desired platform:

   - **Android**:
     ```bash
     flutter run -d <device-id>
     ```
     Find `<device-id>` using `flutter devices`.

   - **iOS**:
     ```bash
     flutter run -d <device-id>
     ```

   - **Web**:
     ```bash
     flutter run -d chrome
     ```

   - **Desktop (Linux/macOS/Windows)**:
     ```bash
     flutter run -d linux
     flutter run -d macos
     flutter run -d windows
     ```

3. Ensure the app connects to the backend by updating the API base URL in `lib/main.dart` to `http://localhost:8000` (or your deployed backend URL).

### 9. Test the Application

- **Sign In**: Use Google Sign-In to authenticate.
- **Upload Receipt**: Use the image picker to upload a receipt image, which will be processed by Google Gemini and stored in Firebase Storage.
- **View Receipts**: Check the `WalletScreen` to view extracted receipt data from Firestore.
- **Interact with Chatbot**: Use the `LuffyChatbotScreen` to query receipt data.
- **Manage Preferences**: Update user preferences via the `PreferenceOnboardingScreen`.
- **Google Wallet**: Add receipts to Google Wallet using the `add_to_google_wallet` package.

## Deployment

### Backend Deployment

Deploy the FastAPI backend to Google Cloud Run:

1. Create a `Dockerfile` in the `backend/` directory:
   ```dockerfile
   FROM python:3.9
   WORKDIR /app
   COPY . .
   RUN pip install -r requirements.txt
   CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
   ```

2. Build and deploy to Google Cloud Run:
   ```bash
   gcloud builds submit --tag gcr.io/[PROJECT-ID]/project-raseed-backend
   gcloud run deploy project-raseed-backend \
     --image gcr.io/[PROJECT-ID]/project-raseed-backend \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

Replace `[PROJECT-ID]` with your Google Cloud project ID.

### Flutter App Deployment

- **Android**: Generate an APK or app bundle:
  ```bash
  flutter build apk --release
  flutter build appbundle --release
  ```
  Upload to the Google Play Store.

- **iOS**: Build and archive for App Store:
  ```bash
  flutter build ios --release
  ```
  Use Xcode to archive and submit to the App Store.

- **Web**: Build and host on Firebase Hosting:
  ```bash
  flutter build web
  firebase deploy
  ```

- **Desktop**: Package for distribution using platform-specific tools (e.g., `flutter_distributor`).

## Troubleshooting

- **Firebase Errors**: Ensure `google-services.json` and `GoogleService-Info.plist` are correctly placed and match your Firebase project.
- **Gemini API Issues**: Verify the API key and check Google Cloud Console for quota limits.
- **CORS Issues**: Update `allow_origins` in `backend/main.py` to include your Flutter app’s origin (e.g., `http://localhost:3000` for web).
- **Image Upload Failures**: Confirm Firebase Storage rules allow authenticated writes.
- **Build Errors**: Ensure all platform-specific dependencies (e.g., CMake, Xcode) are installed.

## Contributing

Contributions to **Project Raseed** are welcome! Please follow these steps:

1. Fork the repository at [GitHub](https://github.com/itzz-keerthi/mugiwara-no-ichimi).
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Team Mugiwara no Ichimi**: For their innovative work during the Agentic AI Day Hackathon.
- **Google Cloud**: For providing Firebase, Gemini, and other tools that power **Project Raseed**.
- **Hack2skill**: For organizing the Agentic AI Day Hackathon.
- **Fi Money**: For supporting the hackathon as the premium partner.
- **Flutter**: For enabling cross-platform development.
- **FastAPI**: For a robust and scalable backend.

