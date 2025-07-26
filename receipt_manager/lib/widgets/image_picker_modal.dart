import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../screens/receipt_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImagePickerModal extends StatefulWidget {
  const ImagePickerModal({super.key});

  @override
  State<ImagePickerModal> createState() => _ImagePickerModalState();
}

class _ImagePickerModalState extends State<ImagePickerModal> {
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source);

  if (!mounted || picked == null) return;
  final currentContext = context;

  setState(() => _isProcessing = true);

  try {
    final file = File(picked.path);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      log("⚠️ No user logged in.");
      throw Exception("User not logged in.");
    }

    final userId = user.uid;
    final uri = Uri.parse('http://192.168.32.150:8000/upload?user_id=$userId');

    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = userId
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(lookupMimeType(file.path) ?? 'application/octet-stream'),
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      log("✅ Upload successful. Waiting for Cloud Extension...");

      await Future.delayed(const Duration(seconds: 4));

      final receiptResponse = await http.get(
        Uri.parse('http://192.168.32.150:8000/latest-receipt?user_id=$userId'),
      );

      log("📦 Latest receipt fetch: ${receiptResponse.statusCode}");

      if (receiptResponse.statusCode == 200) {
        final receiptData = json.decode(receiptResponse.body);

        if (!mounted) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptDetailsScreen(data: receiptData['data']),
          ),
        );
      } else {
        log("❌ Failed to fetch receipt: ${receiptResponse.body}");
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(content: Text("❌ Failed to fetch receipt")),
        );
      }
    } else {
      log("❌ Upload failed: ${response.body}");
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text("❌ Upload failed")),

      );
    }
  } catch (e, stack) {
    log("❌ Exception: $e", stackTrace: stack);
    if (mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  } finally {
    if (mounted) setState(() => _isProcessing = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt),
          title: const Text('Scan via Camera'),
          onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Upload from Gallery'),
          onTap: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }
}
