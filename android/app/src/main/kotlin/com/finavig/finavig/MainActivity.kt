package com.finavig.finavig

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so
// the App Lock can present the biometric prompt on Android.
class MainActivity : FlutterFragmentActivity()
