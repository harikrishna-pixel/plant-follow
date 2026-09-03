import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:plantidentifier/services/wallet_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      try {
        await WalletService.instance.ensureUserWallet(user);
      } catch (e) {
        debugPrint('Wallet bootstrap after Google sign-in failed: $e');
      }
    }
    return userCredential;
  }

  Future<UserCredential> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw Exception('Apple Sign-In is not available on this device. Please use a device with iOS 13.0 or later.');
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      AuthorizationCredentialAppleID? appleCredential;
      try {
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
      } on SignInWithAppleAuthorizationException catch (e) {
        // Handle specific Apple Sign-In errors
        debugPrint('Apple Sign-In Authorization Error: ${e.code} - ${e.message}');
        debugPrint('Apple Sign-In Error Details: ${e.toString()}');
        
        if (e.code == AuthorizationErrorCode.canceled) {
          throw Exception('Sign-in cancelled');
        } else if (e.code == AuthorizationErrorCode.failed) {
          throw Exception('Apple Sign-In failed. Please check your internet connection and try again.');
        } else if (e.code == AuthorizationErrorCode.invalidResponse) {
          throw Exception('Invalid response from Apple. Please try again.');
        } else if (e.code == AuthorizationErrorCode.notHandled) {
          throw Exception('Apple Sign-In not configured. Please check your device settings and try again.');
        } else if (e.code == AuthorizationErrorCode.unknown) {
          // Error 1000 - This is a generic error that can occur for various reasons
          // Common causes: network issues, configuration problems, or temporary Apple service issues
          debugPrint('Apple Sign-In Unknown Error (1000) - This may be a temporary issue');
          throw Exception('Apple Sign-In temporarily unavailable. Please check your internet connection and try again in a moment.');
        }
        throw Exception('Apple Sign-In error: ${e.message ?? 'Please try again.'}');
      } catch (e) {
        // Handle user cancellation or other sign-in errors
        if (e is SignInWithAppleAuthorizationException) {
          rethrow;
        }
        
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('cancel') || 
            errorString.contains('cancelled') ||
            errorString.contains('user cancelled')) {
          throw Exception('Sign-in cancelled');
        }
        debugPrint('Apple Sign-In Error (before credential): ${e.toString()}');
        rethrow;
      }

      // Validate credential before proceeding
      if (appleCredential == null) {
        debugPrint('Apple Sign-In Error: Credential is null');
        throw Exception('Apple Sign-In failed: No credential received. Please try again.');
      }

      // Check if identityToken is null or empty
      if (appleCredential.identityToken == null || 
          appleCredential.identityToken!.isEmpty) {
        debugPrint('Apple Sign-In Error: Invalid or empty identity token');
        throw Exception('Apple Sign-In failed: Invalid identity token. Please try again.');
      }

      // Validate nonce matches (security check)
      if (rawNonce.isEmpty || nonce.isEmpty) {
        debugPrint('Apple Sign-In Error: Invalid nonce');
        throw Exception('Apple Sign-In failed: Security validation error. Please try again.');
      }

      // Debug: Log token info (without exposing sensitive data)
      debugPrint('Apple Sign-In: Identity token received (length: ${appleCredential.identityToken!.length})');
      debugPrint('Apple Sign-In: Raw nonce length: ${rawNonce.length}, Hashed nonce length: ${nonce.length}');
      debugPrint('Apple Sign-In: User ID: ${appleCredential.userIdentifier}');
      debugPrint('Apple Sign-In: Email: ${appleCredential.email ?? "not provided"}');
      debugPrint('Apple Sign-In: Authorization code present: ${appleCredential.authorizationCode != null && appleCredential.authorizationCode!.isNotEmpty}');
      
      // Validate identity token format (should be a JWT)
      final identityTokenParts = appleCredential.identityToken!.split('.');
      if (identityTokenParts.length != 3) {
        debugPrint('Apple Sign-In Error: Identity token is not a valid JWT (expected 3 parts, got ${identityTokenParts.length})');
        throw Exception('Apple Sign-In failed: Invalid token format. Please try again.');
      }
      debugPrint('Apple Sign-In: Identity token is a valid JWT format');

      try {
        // Create OAuth credential for Firebase
        // IMPORTANT: Firebase requires both idToken AND authorizationCode (accessToken)
        // The authorizationCode is required for Firebase to verify the credential with Apple
        // Note: We pass the raw nonce (not the hashed one) to Firebase
        // Firebase will hash it and compare with the nonce sent to Apple
        final oauth = OAuthProvider(
          'apple.com',
        ).credential(
          idToken: appleCredential.identityToken!,
          rawNonce: rawNonce,
          accessToken: appleCredential.authorizationCode, // This is REQUIRED for Firebase
        );

        // Additional validation: check if credential is valid
        if (oauth.idToken == null || oauth.idToken!.isEmpty) {
          debugPrint('Apple Sign-In Error: OAuth credential has invalid idToken');
          throw Exception('Apple Sign-In failed: Invalid credentials. Please try again.');
        }

        debugPrint('Apple Sign-In: OAuth credential created successfully');
        debugPrint('Apple Sign-In: Attempting Firebase sign-in...');

        final userCredential = await _auth.signInWithCredential(oauth);
        
        // Validate user was created
        if (userCredential.user == null) {
          debugPrint('Apple Sign-In Error: User is null after sign-in');
          throw Exception('Apple Sign-In failed: User account not created. Please try again.');
        }
        
        final user = userCredential.user!;
        try {
          await WalletService.instance.ensureUserWallet(user);
        } catch (e) {
          debugPrint('Wallet bootstrap after Apple sign-in failed: $e');
        }
        return userCredential;
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase Auth Error during Apple Sign-In: ${e.code} - ${e.message}');
        debugPrint('Firebase Auth Error Details: ${e.toString()}');
        
        // Re-throw Firebase Auth exceptions with more context
        String errorMessage = 'Apple Sign-In failed. Please try again.';
        
        switch (e.code) {
          case 'invalid-credential':
            // This often happens when:
            // 1. The identity token is expired or invalid
            // 2. There's a mismatch between the nonce
            // 3. Apple Sign-In is not properly configured in Firebase Console
            // 4. Service ID, Team ID, or Private Key mismatch in Firebase Console
            debugPrint('Apple Sign-In: Invalid credential error detected');
            debugPrint('Apple Sign-In: This usually indicates a Firebase Console configuration issue');
            debugPrint('Apple Sign-In: Please verify:');
            debugPrint('  1. Apple Sign-In is enabled in Firebase Console');
            debugPrint('  2. Service ID matches your Apple Developer account');
            debugPrint('  3. Team ID is correct');
            debugPrint('  4. Private Key (.p8 file) is correctly uploaded');
            errorMessage = 'Invalid Apple credentials. Please verify Apple Sign-In is properly configured in Firebase Console. If the issue persists, contact support.';
            break;
          case 'account-exists-with-different-credential':
            errorMessage = 'An account already exists with a different sign-in method. Please use that method to sign in.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Apple Sign-In is not enabled. Please contact support.';
            break;
          case 'user-disabled':
            errorMessage = 'This account has been disabled.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection and try again.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many sign-in attempts. Please wait a moment and try again.';
            break;
          default:
            errorMessage = e.message ?? 'Apple Sign-In failed. Please try again.';
        }
        
        throw FirebaseAuthException(
          code: e.code,
          message: errorMessage,
        );
      } catch (e) {
        debugPrint('Apple Sign-In Error (after credential): ${e.toString()}');
        debugPrint('Apple Sign-In Error Type: ${e.runtimeType}');
        
        // Handle any other errors
        if (e is FirebaseAuthException) {
          rethrow;
        }
        throw Exception('Apple Sign-In failed: ${e.toString()}');
      }
    } catch (e) {
      debugPrint('Apple Sign-In Final Error: ${e.toString()}');
      debugPrint('Apple Sign-In Final Error Type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Future.wait([GoogleSignIn().signOut(), _auth.signOut()]);
  }

  /// Re-authenticate user for sensitive operations like account deletion
  Future<void> reauthenticateUser(User user) async {
    final providerData = user.providerData;
    if (providerData.isEmpty) {
      throw Exception('No provider found for user');
    }

    final providerId = providerData.first.providerId;
    
    if (providerId == 'google.com') {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providerId == 'apple.com') {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      
      // Check if identityToken is null or empty
      if (appleCredential.identityToken == null || 
          appleCredential.identityToken!.isEmpty) {
        throw Exception('Apple re-authentication failed: Invalid identity token. Please try again.');
      }
      
      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode, // Required for Firebase
      );
      await user.reauthenticateWithCredential(oauth);
    } else {
      throw Exception('Unsupported provider: $providerId');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
