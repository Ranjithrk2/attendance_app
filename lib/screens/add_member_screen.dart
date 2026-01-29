import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  File? imageFile;
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;

  final List<String> roles = ['Employee', 'Manager', 'Team Lead', 'Intern'];
  String selectedRole = 'Employee';

  /// 📸 Capture photo
  Future<void> capturePhoto() async {
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      try {
        File compressed = await compressImage(File(photo.path));
        setState(() {
          imageFile = compressed;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error compressing image: $e')),
        );
      }
    }
  }

  /// 🔄 Compress image
  Future<File> compressImage(File file, {int maxWidth = 300, int maxHeight = 300}) async {
    final imageBytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Invalid image file");
    img.Image resized = img.copyResize(image, width: maxWidth, height: maxHeight);
    final jpegBytes = img.encodeJpg(resized, quality: 70);
    final tempPath = file.path.replaceAll('.jpg', '_compressed.jpg');
    final compressedFile = File(tempPath)..writeAsBytesSync(jpegBytes);
    return compressedFile;
  }

  /// 🔄 Convert image to Base64
  Future<String> _imageToBase64(File file) async {
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    if (base64Str.length > 1000000) {
      throw Exception("Image too large for Firestore, compress more");
    }
    return base64Str;
  }

  /// 💾 Save member
  Future<void> saveMember() async {
    if (userIdController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and add a photo')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      const tempPassword = 'Temp@1234';
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'Secondary',
        options: Firebase.app().options,
      );
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      UserCredential user = await secondaryAuth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: tempPassword,
      );
      final uid = user.user!.uid;
      final base64Image = await _imageToBase64(imageFile!);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'userId': userIdController.text.trim(),
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': selectedRole,
        'profileImageBase64': base64Image,
        'firstLogin': true,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secondaryApp.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member added successfully'),
          backgroundColor: Colors.green,
        ),
      );

      userIdController.clear();
      nameController.clear();
      emailController.clear();
      setState(() {
        imageFile = null;
        selectedRole = roles.first;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Add Member', style: TextStyle(color: Colors.cyanAccent)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            /// PHOTO
            GestureDetector(
              onTap: capturePhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.cyanAccent, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.6),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.black,
                  backgroundImage: imageFile != null ? FileImage(imageFile!) : null,
                  child: imageFile == null
                      ? const Icon(Icons.camera_alt, color: Colors.cyanAccent, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 40),

            /// USER ID
            TextField(
              controller: userIdController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('User ID (EMP001)'),
            ),
            const SizedBox(height: 20),

            /// NAME
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Name'),
            ),
            const SizedBox(height: 20),

            /// EMAIL
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            /// ROLE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedRole,
                  dropdownColor: Colors.black87,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.cyanAccent),
                  style: const TextStyle(color: Colors.white),
                  items: roles
                      .map(
                        (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedRole = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 50),

            /// SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveMember,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.cyanAccent.withOpacity(0.5),
                  elevation: 8,
                ).copyWith(
                  foregroundColor: MaterialStateProperty.all(Colors.black),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.cyanAccent, Colors.blueAccent],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                      'Save Member',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
