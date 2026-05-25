import'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beacon_survice.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  // Current logged in user
  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;

  // ── Sign up with email and password ──
  static Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);

      // Get this device's permanent UUID
      final deviceUUID = await BeaconService.getDeviceUUID();

      // Store user info in Firestore
      await _db.collection('users').doc(credential.user!.uid).set({
        'displayName': displayName,
        'email': email,
        'deviceUUID': deviceUUID,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint("SignUp error: $e");
      return false;
    }
  }

  // ── Sign in ──
  static Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      debugPrint("SignIn error: $e");
      return false;
    }
  }

  // ── Sign out ──
  static Future<void> signOut() async {
    await _auth.signOut();
  }

// ── Google Sign-In ─────────────────────────────────────
  // Returns {'success': true, 'displayName': 'Mridul'} on success
  // or {'success': false} on failure
  static Future<Map<String, dynamic>> signInWithGoogle() async {
  try {
    // 1. Safe Initialization (Must be Capital 'G')
    await GoogleSignIn.instance.initialize();

    // 2. Authenticate (Triggers the new modern Android bottom sheet)
    final googleUser = await GoogleSignIn.instance.authenticate();

    // 3. Get the ID Token (Notice we removed the 'await' here for v7!)
    final googleAuth = googleUser.authentication;
    
    // 4. The Firebase Fix: We ONLY pass the idToken. No accessToken needed!
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // 5. Authenticate with Firebase
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final displayName = userCredential.user?.displayName ?? "Unknown";

    debugPrint("BEACON: Google Sign In successful: $displayName");

    // 6. Return our custom router map (with the Bug #2 bypass applied!)
    return {
      'success': true,
      'isNewUser': false, // Forces the UI to skip the manual name entry screen
      'googleName': displayName,
    };
    
  } catch (e) {
    debugPrint("BEACON: Google Sign In failed: $e");
    return {'success': false};
  }
}

static Future<void> updateDisplayName(String name) async {
  final user = _auth.currentUser;
  if (user == null) return;
  
  await user.updateDisplayName(name);
  await _db.collection('users').doc(user.uid).update({
    'displayName': name,
  });
}

  // ── Look up who owns a detected device UUID ──
  // This is the key method — when we detect an "App User"
  // we query Firestore to find their real name
  static Future<String?> getDisplayNameForDevice(String deviceUUID) async {
    try {
      final query = await _db
          .collection('users')
          .where('deviceUUID', isEqualTo: deviceUUID)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return query.docs.first['displayName'] as String?;
    } catch (e) {
      debugPrint("Lookup error: $e");
      return null;
    }
  }

  static Future<void> loadAndSaveDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final displayName = doc['displayName'] as String?;
        if (displayName != null) {
          // Save to local storage or state management
          debugPrint("Loaded display name: $displayName");
        }
      }
    } catch (e) {
      debugPrint("Error loading display name: $e");
    }
}
static Future<bool> needsDisplayName() async {
  final user = _auth.currentUser;
  if (user == null) return false;

  // First load from Firestore to sync local storage
  await loadAndSaveDisplayName();

  // Now check local storage
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('display_name');
  
  // Only ask for name if truly empty or default
  return saved == null || saved.isEmpty || saved == 'App User';
}
}