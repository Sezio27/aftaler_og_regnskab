import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> handleDelete({
  required BuildContext context,
  required String componentLabel,
  required Future<void> Function() onDelete,
  bool popOnSuccess = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final ok =
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Slet $componentLabel?'),
          content: const Text('Dette kan ikke fortrydes.'),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(false),
              child: const Text('Annuller'),
            ),
            TextButton(
              onPressed: () => ctx.pop(true),
              child: const Text('Slet'),
            ),
          ],
        ),
      ) ??
      false;

  if (!ok || !context.mounted) return;

  try {
    await onDelete();
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('$componentLabel slettet')));
    if (popOnSuccess) context.pop();
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Kunne ikke slette: $e')));
  }
}

Future<void> handleSave({
  required BuildContext context,
  String? Function()? validate,
  required Future<bool> Function() onSave,
  VoidCallback? onSuccess,
  String successMessage = 'Opdateret',
  String? Function()? errorText,
}) async {
  FocusScope.of(context).unfocus();

  final String? validationError = validate?.call();
  if (validationError != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
    }
    return;
  }

  bool ok;
  try {
    ok = await onSave();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kunne ikke gemme: $e')));
    }
    return;
  }

  if (!context.mounted) return;

  if (ok) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
    onSuccess?.call();
  } else {
    final msg = errorText?.call() ?? 'Ukendt fejl';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
