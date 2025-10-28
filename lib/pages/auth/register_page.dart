import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/forgot_password_dialog.dart';
import '../../data/us_states.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _idExpiryController = TextEditingController();
  final _authService = AuthService();
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  String _selectedAccountType = 'individual';
  String? _selectedCity;
  List<String> _availableCities = [];
  File? _selectedDocument;
  String? _documentUrl;

  // Phone number formatter
  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _updateAvailableCities('Ohio');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _idNumberController.dispose();
    _dateOfBirthController.dispose();
    _idExpiryController.dispose();
    super.dispose();
  }

  void _updateAvailableCities(String? stateName) {
    if (stateName == null) {
      setState(() {
        _availableCities = [];
        _selectedCity = null;
      });
      return;
    }

    final state = usStates.firstWhere(
      (state) => state.name == stateName,
      orElse: () => usStates.first,
    );

    setState(() {
      _availableCities = state.cities;
      _selectedCity = null;
    });
  }

  // Validate US phone number
  bool _isValidUSPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    // Check if it's exactly 10 digits
    return digitsOnly.length == 10;
  }

  Future<void> _pickDocument() async {
    try {
      final result = await showDialog<ImageSource>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Select Source'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: const Text('Camera'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
      );

      if (result != null) {
        final pickedFile = await _imagePicker.pickImage(
          source: result,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          setState(() {
            _selectedDocument = File(pickedFile.path);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking document: $e')));
    }
  }

  Future<String?> _uploadDocument(String userId) async {
    if (_selectedDocument == null) return null;

    try {
      final fileName =
          '${_selectedAccountType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('user_documents/$userId/$fileName');

      await ref.putFile(_selectedDocument!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading document: $e')));
      return null;
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate phone number format
    if (!_isValidUSPhoneNumber(_phoneController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid US phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate document upload for commercial accounts only
    if (_selectedAccountType == 'commercial' && _selectedDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a document to verify your business account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create user with email and password
      final user = await _authService.signUpWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
        _firstNameController.text,
        _lastNameController.text,
        _phoneMaskFormatter.getUnmaskedText(),
        _selectedAccountType,
        '',
        _selectedCity ?? '',
      );

      if (!mounted) return;

      // Upload document and save user details (only for commercial accounts)
      if (_selectedAccountType == 'commercial') {
        _documentUrl = await _uploadDocument(user.id);
        if (_documentUrl == null) {
          throw Exception('Failed to upload document');
        }
      }
      await _saveUserDetails(user.id);

      await _authService.signOut();

      // Show verification dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Verify Your Email'),
            content: Text(
              'A verification email has been sent to ${_emailController.text}. Please verify your email before logging in.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.pushReplacementNamed(
                    context,
                    '/login',
                  ); // Go to login page
                },
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  await _authService.sendVerificationEmail();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification email sent again'),
                    ),
                  );
                },
                child: const Text('Resend Email'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserDetails(String userId) async {
    try {
      Map<String, dynamic> userDetails = {
        'userId': userId,
        'accountType': _selectedAccountType,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Only add document URL for commercial accounts
      if (_selectedAccountType == 'commercial' && _documentUrl != null) {
        userDetails['documentUrl'] = _documentUrl;
      }

      if (_selectedAccountType == 'commercial') {
        userDetails.addAll({
          'businessName': _businessNameController.text,
          'businessAddress': _businessAddressController.text,
        });
      } else {
        userDetails.addAll({
          'idNumber': _idNumberController.text,
          'dateOfBirth': _dateOfBirthController.text,
          'idExpiry': _idExpiryController.text,
        });
      }

      await _firestore.collection('user_details').doc(userId).set(userDetails);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving user details: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                SvgPicture.asset(
                  'assets/images/cvs_recycling_logo.svg',
                  height: 80,
                ),
                const SizedBox(height: 32),
                // Sign Up Text
                const Text(
                  'Create your account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Account Type Radio Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Individual'),
                        value: 'individual',
                        groupValue: _selectedAccountType,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAccountType = value;
                            });
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Commercial'),
                        value: 'commercial',
                        groupValue: _selectedAccountType,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAccountType = value;
                            });
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // First Name Field
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    hintText: 'First Name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'First name is required'
                              : null,
                ),
                const SizedBox(height: 16),
                // Last Name Field
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    hintText: 'Last Name',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator:
                      (value) =>
                          value?.isEmpty ?? true
                              ? 'Last name is required'
                              : null,
                ),
                const SizedBox(height: 16),
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Email is required';
                    }
                    if (!value!.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_phoneMaskFormatter],
                  decoration: InputDecoration(
                    hintText: 'Phone',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Phone number is required';
                    }
                    if (!_isValidUSPhoneNumber(value!)) {
                      return 'Please enter a valid US phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Region Field
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    hintText: 'Region',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items:
                      _availableCities.map((city) {
                        return DropdownMenuItem(value: city, child: Text(city));
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your region';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Password is required';
                    }
                    if (value!.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                // Additional Information Section
                if (_selectedAccountType == 'commercial') ...[
                  const Text(
                    'Business Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please upload one of the following documents to verify your business:',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Vendor License (photo or scanned copy)\n• LLC or Incorporation Certificate',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  // Business Name Field
                  TextFormField(
                    controller: _businessNameController,
                    decoration: InputDecoration(
                      hintText: 'Business Name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (_selectedAccountType == 'commercial' &&
                          (value?.isEmpty ?? true)) {
                        return 'Business name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Business Address Field
                  TextFormField(
                    controller: _businessAddressController,
                    decoration: InputDecoration(
                      hintText: 'Business Address',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (_selectedAccountType == 'commercial' &&
                          (value?.isEmpty ?? true)) {
                        return 'Business address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Document Upload Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickDocument,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _selectedDocument == null
                          ? 'Upload Business Document'
                          : 'Document Selected',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedDocument != null
                              ? Colors.green[100]
                              : Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_selectedDocument != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Document selected: ${_selectedDocument!.path.split('/').last}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
                const SizedBox(height: 32),
                // Sign Up Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
