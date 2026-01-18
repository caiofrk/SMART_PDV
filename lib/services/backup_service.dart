import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class BackupService {
  static Future<void> exportDatabase(BuildContext context) async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabaseFilePath();
      final file = File(dbPath);

      if (await file.exists()) {
        final box = context.findRenderObject() as RenderBox?;
        
        await Share.shareXFiles(
          [XFile(dbPath)],
          text: 'Backup do PDV - ${DateTime.now().toString()}',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro: Banco de dados não encontrado.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar backup: $e')),
      );
    }
  }
}
