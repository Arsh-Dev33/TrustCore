# TrustCore Face Verification Plugin - Host App Integration Guide

The `trust_core` plugin has been completely refactored. The internal database, offline registration, and local similarity-matching functionalities have been removed. 

The plugin now serves as a **single-function, real-time face validation utility** entirely running offline without a required backend or signup.

## 1. Core Changes
* **No Database**: `trust_core` no longer stores any faces on the device.
* **No Registration**: The `TrustCore.signup()` method has been removed.
* **No Local Verification**: The `TrustCore.verify()` method has been removed.
* **New Flow**: The plugin now handles the camera UI and validates the user against live criteria (liveness, single face, open eyes, no mask, etc.) and upon success, simply returns a `base64` image with precision GPS coordinates wrapped in a `TrustCoreResult`.

## 2. Updated Installation

### Requirements
* Flutter SDK: `>=3.24.0`
* Android: `minSdkVersion 21` or higher.
* iOS: `14.0` or higher.

The plugin requires two **TFLite models** for mask and glasses detection. 
1. `mask_detector.tflite`
2. `glasses_detector.tflite`

Ensure these models are placed inside `assets/models/` in the `trust_core` plugin itself, or handled gracefully through your host application's asset declarations. 

### Platform Permissions
Your host app must declare these permissions. 

**Android (`android/app/src/main/AndroidManifest.xml`)**
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<application>
  <meta-data
    android:name="com.google.mlkit.vision.DEPENDENCIES"
    android:value="face,facemesh" />
</application>
```

**iOS (`ios/Runner/Info.plist`)**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used for face detection and verification.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location is captured at the time of face verification.</string>
```

## 3. New Usage Implementation

All backend processing, face comparisons, and storage logic **MUST** now be handled by the host application. 

Replace the old `signup` and `verify` calls with the single new `capture` function:

```dart
import 'package:trust_core/trust_core.dart';

class MyVerificationScreen extends StatefulWidget {
  @override
  _MyVerificationScreenState createState() => _MyVerificationScreenState();
}

class _MyVerificationScreenState extends State<MyVerificationScreen> {
  
  Future<void> _runFaceVerification() async {
    // 1. Launch the TrustCore validation camera
    // This handles permissions and UI automatically
    final TrustCoreResult? result = await TrustCore.capture(context);

    if (result != null) {
      // 2. Validation Passed! 
      // The user successfully followed all instructions (blinked, no mask, etc).
      
      final String base64Image = result.base64Image;
      final double latitude = result.latitude;
      final double longitude = result.longitude;
      final DateTime captureTime = result.capturedAt;

      // 3. YOUR RESPONSIBILITY:
      // Send the base64 image to your backend for similarity matching
      // against the user's registered ID/Face profile.
      print("Sending face data to backend for user validation at: $latitude, $longitude");
      
      // Example backend payload:
      // await myBackend.verifyFace(userId: '123', faceBase64: base64Image);

    } else {
      // User cancelled the camera stream or backed out
      print("Verification cancelled by user.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _runFaceVerification,
          child: Text('Run Identity Check'),
        ),
      ),
    );
  }
}
```

## 4. Live Checks Guaranteed by Plugin
When `TrustCore.capture()` returns a valid `TrustCoreResult`, the host app is guaranteed that the returned image successfully passed the following checks locally on the device:
1. **Liveness:** User blinked (avoids static photo spoofing).
2. **Single Face:** Only one person is in the frame.
3. **Eyes Open:** Both eyes of the user were clearly open.
4. **Visibility:** The face was not partially covered (verified via Google ML Kit Face Mesh).
5. **No Spoofs:** No masks or glasses/spectacles were detected (verified via TFLite).
6. **Location:** GPS coordinates were active and successfully captured.
