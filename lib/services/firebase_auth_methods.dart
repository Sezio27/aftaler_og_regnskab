import 'dart:async';

import 'package:aftaler_og_regnskab/data/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/data/cache/service_cache.dart';
import 'package:aftaler_og_regnskab/utils/showOtpDialog.dart';
import 'package:aftaler_og_regnskab/utils/showSnackBar.dart';
import 'package:aftaler_og_regnskab/viewModel/client_view_model.dart';
import 'package:aftaler_og_regnskab/viewModel/service_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class FirebaseAuthMethods {
  final FirebaseAuth _auth;
  FirebaseAuthMethods(this._auth);

  // FOR EVERY FUNCTION HERE
  // POP THE ROUTE USING: Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);

  // GET USER DATA
  // using null check operator since this method should be called only
  // when the user is logged in
  User get user => _auth.currentUser!;

  // STATE PERSISTENCE STREAM
  Stream<User?> get authState => FirebaseAuth.instance.authStateChanges();
  // OTHER WAYS (depends on use case):
  // Stream get authState => FirebaseAuth.instance.userChanges();
  // Stream get authState => FirebaseAuth.instance.idTokenChanges();
  // KNOW MORE ABOUT THEM HERE: https://firebase.flutter.dev/docs/auth/start#auth-state

  // PHONE SIGN IN
  Future<(String verificationId, int? resendToken)> startPhoneVerification(
    String phoneNumber, {
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<(String, int?)>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential cred) async {
          // Android instant verification / auto-retrieval
          try {
            await _auth.signInWithCredential(cred);
          } catch (_) {
            /* ignore */
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete((verificationId, resendToken));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Still return an id if timeout fires before codeSent (rare)
          if (!completer.isCompleted) {
            completer.complete((verificationId, null));
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    // ✅ Always returns a value or throws — no “body might complete normally”
    return completer.future;
  }

  Future<UserCredential> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(cred);
  }

  // SIGN OUT

  Future<void> signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      if (!context.mounted) return;
      if (context.mounted) context.go('/gate');
    } on FirebaseAuthException catch (e) {
      showSnackBar(context, e.message ?? 'Kunne ikke logge ud');
    } catch (e) {
      showSnackBar(context, 'Kunne ikke logge ud');
    }
  }

  // DELETE ACCOUNT
  Future<void> deleteAccount(BuildContext context) async {
    try {
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      showSnackBar(context, e.message!); // Displaying the error message
      // if an error of requires-recent-login is thrown, make sure to log
      // in user again and then delete account.
    }
  }
}
