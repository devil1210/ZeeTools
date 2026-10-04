import 'package:flutter/material.dart';

Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String confirmLabel, String cancelLabel = 'Cancelar'}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return confirmed ?? false;
}
