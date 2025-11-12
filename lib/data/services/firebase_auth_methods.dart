import 'dart:async';

import 'package:aftaler_og_regnskab/domain/cache/client_cache.dart';
import 'package:aftaler_og_regnskab/domain/cache/service_cache.dart';
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

  User get user => _auth.currentUser!;

  Stream<User?> get authState => FirebaseAuth.instance.authStateChanges();

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
          try {
            await _auth.signInWithCredential(cred);
          } catch (_) {}
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
          if (!completer.isCompleted) {
            completer.complete((verificationId, null));
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

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

  Future<void> deleteAccount(BuildContext context) async {
    try {
      await _auth.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      showSnackBar(context, e.message!);
    }
  }
}
