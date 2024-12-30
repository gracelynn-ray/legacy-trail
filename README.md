# Legacy Trail – iOS Application

Legacy Trail is an iOS application designed to help users create, store, and explore time capsules and memories through an engaging and intuitive interface.

## Features

- **User Interface**
  - Intuitive and visually appealing interface with buttons, table views, and collection views.
  - Designed using Xcode Storyboard and UIKit for consistency and ease of use.

- **App Navigation**
  - Seamless navigation between major pages using a tab bar controller.
  - Ensures a smooth and user-friendly experience.

- **User Authentication**
  - Secure login and registration system implemented with Firebase Authentication.
  - Provides personalized access for each user.

- **Profile Screen**
  - Displays user-specific information such as username and email.
  - Allows customization of profile picture for a personalized experience.

- **Interactive Map**
  - Map view displays the user's current location using MapKit.
  - Pins represent memories with associated locations, providing geographical visualization.
  - Users can long-press on the map to create bucket list items.

- **Memories Management**
  - Memories are stored in Firestore and displayed in a vertical-scrolling collection view.
  - Tap a memory to view details, edit, or delete it.
  - Users can adjust memory locations during creation or editing.

- **Time Capsules**
  - Create and edit time capsules with scheduled availability dates.
  - View received capsules only after their availability date.
  - Share memories as part of time capsules with specific details and location information.

- **Data Synchronization**
  - Real-time synchronization of user data across devices using Firebase Firestore.
  - Ensures all memories and time capsules are up-to-date.

## Technologies Used

- **Swift**: Core programming language for iOS development.
- **MapKit**: Enables interactive map features to pin and explore memories.
- **Firebase**:
  - **Authentication**: Secure user login and session management.
  - **Firestore**: Real-time database for storing and retrieving photos.
- **Xcode and Storyboard**: Tools for building and designing the application UI.
