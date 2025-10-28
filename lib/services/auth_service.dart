import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user state
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Helper method to get user-friendly error messages
  String _getErrorMessage(String errorCode) {
    print(errorCode);
    switch (errorCode) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'invalid-credential':
        return 'You entered invalid credentials.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'too-many-requests':
        return 'Too many unsuccessful login attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Sign in with email and password
  Future<UserModel> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        // Resend verification email
        await userCredential.user!.sendEmailVerification();
        // Sign out the user since they can't proceed
        await _auth.signOut();
        throw Exception('Please verify your email. A new verification email has been sent.');
      }

      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        // Sign out if user document doesn't exist
        await _auth.signOut();
        throw Exception('User not found');
      }

      final userData = UserModel.fromJson(userDoc.data()!);
      if (!userData.isActive) {
        // Sign out if account is inactive
        await _auth.signOut();
        throw Exception('Account is inactive');
      }

      return userData;
    } on FirebaseAuthException catch (e) {
      // Make sure user is signed out on any Firebase auth error
      await _auth.signOut();
      throw _getErrorMessage(e.code);
    } catch (e) {
      // Sign out on any other error
      await _auth.signOut();
      throw e.toString();
    }
  }

  // Sign up with email and password
  Future<UserModel> signUpWithEmailAndPassword(
    String email,
    String password,
    String firstName,
    String lastName,
    String? phone,
    String accountType,
    String? state,
    String? city,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      final newUser = UserModel(
        id: userCredential.user!.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        createdAt: DateTime.now(),
        isActive: true,
        accountType: accountType,
        state: state,
        city: city,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set(newUser.toJson());

      // Sign out after successful registration since email needs to be verified
      // await _auth.signOut();
      return newUser;
    } on FirebaseAuthException catch (e) {
      // Make sure user is signed out on any Firebase auth error
      await _auth.signOut();
      throw _getErrorMessage(e.code);
    } catch (e) {
      // Sign out on any other error
      await _auth.signOut();
      throw e.toString();
    }
  }

  // Send verification email again
  Future<void> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw e.toString();
    }
  }

  // Check if email is verified
  bool isEmailVerified() {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  // Save user data to Firestore
  Future<void> saveUserData(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toJson());
    } catch (e) {
      throw Exception('Failed to save user data: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw e.toString();
    }
  }

  // Delete user account
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Re-authenticate user before deletion
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user from Firebase Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw e.toString();
    }
  }
}
