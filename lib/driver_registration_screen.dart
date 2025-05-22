import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'constants.dart';
import 'login_screen.dart';

/// A screen for driver registration, allowing users to input personal details,
/// upload optional KYC documents, and provide bank information.
class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Controllers
  final PageController _pageController = PageController();
  final _personalFormKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();

  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // State
  int _currentPage = 0;
  bool _isLoading = false;
  String _phoneNumber = '';
  String _userId = '';
  File? _panCard;
  File? _businessReg;
  File? _aadharCard;
  Uint8List? _panCardBytes;
  Uint8List? _businessRegBytes;
  Uint8List? _aadharCardBytes;

  @override
  void initState() {
    super.initState();
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    // Fetch initial user data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _phoneNumber = _sanitizePhoneNumber(user.phoneNumber ?? '');
      _userId = user.uid;
      debugPrint('User initialized: UID = $_userId, Phone = $_phoneNumber');
    } else {
      debugPrint('No user logged in during initState');
    }

    // Set up authentication state listener
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        debugPrint('User signed out. Navigating to login screen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>  LoginScreen()),
        );
      } else {
        setState(() {
          _phoneNumber = _sanitizePhoneNumber(user.phoneNumber ?? '');
          _userId = user.uid;
        });
        debugPrint('User authenticated: UID = $_userId, Phone = $_phoneNumber');
      }
    });
  }

  /// Sanitizes the phone number to ensure it's valid for Firestore document ID.
  String _sanitizePhoneNumber(String phoneNumber) {
    // Remove spaces, dashes, and other special characters
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    debugPrint('Sanitized phone number: $sanitized');
    return sanitized;
  }

  /// Navigates to the next page or submits the form.
  void _nextPage() {
    if (_currentPage == 0 && !_personalFormKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields', success: false);
      return;
    }
    if (_currentPage == 2 && !_bankFormKey.currentState!.validate()) {
      _showSnackBar('Please fill all required bank details', success: false);
      return;
    }

    if (_currentPage < 2) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitForm();
    }
  }

  /// Navigates to the previous page.
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Picks a document for upload.
  Future<void> _pickDocument(int docType) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            switch (docType) {
              case 1:
                _panCardBytes = bytes;
                break;
              case 2:
                _businessRegBytes = bytes;
                break;
              case 3:
                _aadharCardBytes = bytes;
                break;
            }
          });
        } else {
          setState(() {
            switch (docType) {
              case 1:
                _panCard = File(pickedFile.path);
                break;
              case 2:
                _businessReg = File(pickedFile.path);
                break;
              case 3:
                _aadharCard = File(pickedFile.path);
                break;
            }
          });
        }
        _showSnackBar('Document selected successfully', success: true);
      }
    } catch (e) {
      _showSnackBar('Error picking document: $e', success: false);
    }
  }

  /// Uploads a document to Firebase Storage and returns the download URL.
  Future<String?> _uploadToStorage(String storagePath, int docType) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      if (kIsWeb) {
        Uint8List? bytes;
        switch (docType) {
          case 1:
            bytes = _panCardBytes;
            break;
          case 2:
            bytes = _businessRegBytes;
            break;
          case 3:
            bytes = _aadharCardBytes;
            break;
        }
        if (bytes != null) {
          await storageRef.putData(bytes);
          return await storageRef.getDownloadURL();
        }
      } else {
        File? file;
        switch (docType) {
          case 1:
            file = _panCard;
            break;
          case 2:
            file = _businessReg;
            break;
          case 3:
            file = _aadharCard;
            break;
        }
        if (file != null) {
          await storageRef.putFile(file);
          return await storageRef.getDownloadURL();
        }
      }
      return '';
    } catch (e) {
      debugPrint('Error uploading document: $e');
      _showSnackBar('Failed to upload document: $e', success: false);
      return '';
    }
  }

  /// Submits the registration form and saves data to Firestore.
  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    try {
      // Verify authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _phoneNumber.isEmpty) {
        debugPrint('Authentication error: User is null or phone number is empty');
        _showSnackBar('Not authenticated. Please log in again.', success: false);
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>  LoginScreen()),
        );
        return;
      }
      debugPrint('Submitting form for user: UID = $_userId, Phone = $_phoneNumber');

      // Upload documents (all optional)
      String? panUrl = '';
      String? regUrl = '';
      String? aadharUrl = '';
      if (kIsWeb ? _panCardBytes != null : _panCard != null) {
        panUrl = await _uploadToStorage('kyc/$_userId/pan_${DateTime.now().millisecondsSinceEpoch}', 1);
      }
      if (kIsWeb ? _businessRegBytes != null : _businessReg != null) {
        regUrl = await _uploadToStorage('kyc/$_userId/businessReg_${DateTime.now().millisecondsSinceEpoch}', 2);
      }
      if (kIsWeb ? _aadharCardBytes != null : _aadharCard != null) {
        aadharUrl = await _uploadToStorage('kyc/$_userId/aadhar_${DateTime.now().millisecondsSinceEpoch}', 3);
      }

      // Save to userDetails
      debugPrint('Writing to userDetails/$_phoneNumber');
      await FirebaseFirestore.instance.collection('userDetails').doc(_phoneNumber).set({
        'userId': _userId,
        'phoneNo': _phoneNumber,
        'name': _nameController.text.trim(),
        'photoUrl': '',
        'userType': 'client',
        'createdAt': FieldValue.serverTimestamp(),
        'isKycVerified': false,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      debugPrint('Successfully wrote to userDetails/$_phoneNumber');

      // Save to clientCreditData
      debugPrint('Writing to clientCreditData/$_phoneNumber');
      await FirebaseFirestore.instance.collection('clientCreditData').doc(_phoneNumber).set({
        'clientId': _phoneNumber,
        'uId': _userId,
        'phoneNo': _phoneNumber,
        'creditLimit': 0.0,
        'creditUsed': 0.0,
        'creditBal': 0.0,
        'currInterestRate': 0,
        'totalRepayAmt': 0.0,
        'nextRepayAt': FieldValue.serverTimestamp(),
        'kycDocs': {
          'pan': panUrl ?? '',
          'businessReg': regUrl ?? '',
          'aadhar': aadharUrl ?? '',
          'gst': '',
        },
        'bankDetails': {
          'bankName': _bankNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'ifsc': _ifscController.text.trim(),
        },
        'address': _addressController.text.trim(),
        'email': _emailController.text.trim(),
      });
      debugPrint('Successfully wrote to clientCreditData/$_phoneNumber');

      _showSnackBar('Registration successful!', success: true);

      // Navigate to LoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  LoginScreen()),
      );
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        _showSnackBar('Permission denied. Please check your authentication status.', success: false);
      } else {
        _showSnackBar('Registration failed: ${e.message}', success: false);
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      _showSnackBar('Registration failed: $e', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Shows a styled SnackBar for success or error messages.
  void _showSnackBar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.accentColor : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Driver Registration',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _currentPage > 0 ? _previousPage() : Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.backgroundDark, AppColors.backgroundLight],
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withOpacity(0.1),
              ),
            ),
          ),
          // Animated wave
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => ClipPath(
                clipper: WaveClipper(animation: _animationController.value),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryColor, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Processing Registration...',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
            )
                : FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      children: List.generate(3, (index) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _currentPage >= index
                                ? AppColors.primaryColor
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      )),
                    ),
                  ),
                  // Page title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _getPageTitle(),
                        style: AppTextStyles.heading1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Page subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _getPageSubtitle(),
                        style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Form pages
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildPersonalInfoPage(),
                        _buildKycDocumentsPage(),
                        _buildBankInfoPage(),
                      ],
                    ),
                  ),
                  // Bottom navigation
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage < 2 ? 'Continue' : 'Submit',
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage < 2 ? Icons.arrow_forward : Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the title for the current page.
  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'KYC Documents';
      case 2:
        return 'Bank Information';
      default:
        return '';
    }
  }

  /// Returns the subtitle for the current page.
  String _getPageSubtitle() {
    switch (_currentPage) {
      case 0:
        return 'Please provide your personal details';
      case 1:
        return 'Upload optional identification documents';
      case 2:
        return 'Add your bank details for receiving credits';
      default:
        return '';
    }
  }

  /// Builds the personal information page.
  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display phone number
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registering with:',
                          style: AppTextStyles.body.copyWith(color: Colors.white70),
                        ),
                        Text(
                          _phoneNumber.isEmpty ? 'No phone number available' : _phoneNumber,
                          style: AppTextStyles.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) => value!.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value!.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _addressController,
              label: 'Address',
              icon: Icons.home_outlined,
              maxLines: 3,
              validator: (value) => value!.isEmpty ? 'Address is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the KYC documents page.
  Widget _buildKycDocumentsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDocumentUploadCard(
            title: 'PAN Card',
            subtitle: 'Upload your PAN card (optional)',
            icon: Icons.credit_card,
            hasFile: kIsWeb ? _panCardBytes != null : _panCard != null,
            onTap: () => _pickDocument(1),
          ),
          const SizedBox(height: 16),
          _buildDocumentUploadCard(
            title: 'Business Registration',
            subtitle: 'Upload your business registration document (optional)',
            icon: Icons.business,
            hasFile: kIsWeb ? _businessRegBytes != null : _businessReg != null,
            onTap: () => _pickDocument(2),
          ),
          const SizedBox(height: 16),
          _buildDocumentUploadCard(
            title: 'Aadhar Card',
            subtitle: 'Upload your Aadhar card (optional)',
            icon: Icons.badge,
            hasFile: kIsWeb ? _aadharCardBytes != null : _aadharCard != null,
            onTap: () => _pickDocument(3),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your documents are secure and will only be used for verification purposes.',
                    style: AppTextStyles.body.copyWith(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a document upload card.
  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool hasFile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppColors.accentColor.withOpacity(0.5) : Colors.grey.shade800,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasFile ? AppColors.accentColor.withOpacity(0.1) : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasFile ? Icons.check : icon,
                color: hasFile ? AppColors.accentColor : AppColors.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFile ? 'Document uploaded' : subtitle,
                    style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.upload_file,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the bank information page.
  Widget _buildBankInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _bankFormKey,
        child: Column(
          children: [
            _buildNeonTextField(
              controller: _bankNameController,
              label: 'Bank Name',
              icon: Icons.account_balance,
              validator: (value) => value!.isEmpty ? 'Bank name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _accountNumberController,
              label: 'Account Number',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Account number is required' : null,
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _ifscController,
              label: 'IFSC Code',
              icon: Icons.confirmation_number,
              validator: (value) => value!.isEmpty ? 'IFSC code is required' : null,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your bank details are secure and will only be used for credit transactions.',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a neon-styled text field.
  Widget _buildNeonTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade800 : AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            readOnly: readOnly,
            validator: validator,
            style: AppTextStyles.body.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: readOnly ? null : 'Enter $label...',
              hintStyle: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
              prefixIcon: Icon(
                icon,
                color: AppColors.primaryColor.withOpacity(0.7),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

/// Animated wave clipper for the header.
class WaveClipper extends CustomClipper<Path> {
  final double animation;

  WaveClipper({required this.animation});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.7);

    final firstControlPoint = Offset(
      size.width / 4,
      size.height + sin(animation * 2 * pi) * 10,
    );
    final firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(
      size.width - (size.width / 3.25),
      size.height - 65 + cos(animation * 2 * pi) * 10,
    );
    final secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(WaveClipper oldClipper) => true;
}