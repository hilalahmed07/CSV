import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/rating_display.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  UserModel? _user;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _user = UserModel.fromJson(doc.data()!);
        });
      }
    }
  }

  Future<void> _updateProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');

      await storageRef.putFile(File(image.path));
      final photoUrl = await storageRef.getDownloadURL();

      // Update user document with new photo URL
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': photoUrl});

      // Update local state
      setState(() {
        _user = _user?.copyWith(photoUrl: photoUrl);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile image: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editProfile() async {
    // Show dialog to edit name
    final firstNameController = TextEditingController(text: _user?.firstName);
    final lastNameController = TextEditingController(text: _user?.lastName);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Name'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, {'firstName': firstNameController.text, 'lastName': lastNameController.text}),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'firstName': result['firstName'], 'lastName': result['lastName']});
        setState(() {
          _user = _user?.copyWith(firstName: result['firstName'], lastName: result['lastName']);
        });
      }
    }
  }

  Future<void> _updatePaypalEmail() async {
    final TextEditingController controller = TextEditingController(text: _user?.paypalEmail);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Update PayPal Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This is where you will get refunds in case your payout is greater than fee of the order.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'PayPal Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
            ],
          ),
    );

    if (result != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'paypalEmail': result});
        setState(() {
          _user = _user?.copyWith(paypalEmail: result);
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog with password input
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently removed.'),
                const SizedBox(height: 16),
                const Text('Please enter your password to confirm:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (passwordController.text.isNotEmpty) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your password')));
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true && passwordController.text.isNotEmpty) {
      setState(() => _isLoading = true);

      try {
        // Delete profile image from Firebase Storage if it exists
        if (_user?.photoUrl != null) {
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
              await storageRef.delete();
            }
          } catch (e) {
            // Continue with account deletion even if image deletion fails
            print('Error deleting profile image: $e');
          }
        }

        // Delete account using AuthService with password
        await authService.deleteAccount(passwordController.text);

        // Navigate to login page
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _user == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Profile Image
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _updateProfileImage,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: _user!.photoUrl != null ? NetworkImage(_user!.photoUrl!) : null,
                            child: _user!.photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                          ),
                        ),
                        if (_isLoading) const Positioned.fill(child: CircularProgressIndicator()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Name and Email
                    Text(_user!.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_user!.email, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    if (_user!.phone != null) Text(_user!.phone!, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 24),
                    // Options List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Edit profile'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _editProfile,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.star),
                              title: const Text('Rating'),
                              trailing: RatingDisplay(rating: _user!.averageRating, size: 16),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.payment),
                              title: const Text('PayPal Email'),
                              subtitle:
                                  _user!.paypalEmail != null
                                      ? Text(_user!.paypalEmail!)
                                      : const Text('Not set', style: TextStyle(color: Colors.grey)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _updatePaypalEmail,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.red),
                              title: const Text('Logout', style: TextStyle(color: Colors.red)),
                              onTap: () async {
                                await authService.signOut();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context, '/login');
                                }
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.delete_forever, color: Colors.red),
                              title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                              onTap: _deleteAccount,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
