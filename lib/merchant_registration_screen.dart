import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import 'constants.dart';
import 'login_screen.dart';

/// A screen for merchant registration, allowing users to input business details,
/// upload documents, and manage store information with QR code generation.
class MerchantRegistrationScreen extends StatefulWidget {
  const MerchantRegistrationScreen({super.key});

  @override
  State<MerchantRegistrationScreen> createState() => _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState extends State<MerchantRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // Form keys for validation
  final _personalFormKey = GlobalKey<FormState>();
  final _storeFormKey = GlobalKey<FormState>();

  // Text editing controllers
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();

  // Page and animation controllers
  final PageController _pageController = PageController();
  final ConfettiController _confettiController =
  ConfettiController(duration: const Duration(seconds: 5));
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // State variables
  String _serviceType = 'fuel';
  bool _isLoading = false;
  String _userId = '';
  String _storeId = '';
  int _currentPage = 0;

  // File storage for document uploads
  Uint8List? _companyPanBytes;
  Uint8List? _businessRegBytes;
  Uint8List? _gstBytes;
  File? _companyPan;
  File? _businessReg;
  File? _gst;

  // Document URLs
  String? _panUrl;
  String? _regUrl;
  String? _gstUrl;

  // List of stores
  final List<Map<String, dynamic>> _stores = [];

  // QR code data
  String? _qrCodeData;
  Uint8List? _qrImageBytes;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.settings = const Settings();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Set up authentication state listener
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        debugPrint('User signed out. Navigating to login screen...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        _phoneController.text = user.phoneNumber ?? '';
        _userId = user.uid;
        debugPrint('User authenticated: UID = $_userId, Phone = ${_phoneController.text}');
      }
    });

    // Initialize user data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _phoneController.text = user.phoneNumber ?? '';
      _userId = user.uid;
      debugPrint('User initialized: UID = $_userId, Phone = ${_phoneController.text}');
    } else {
      debugPrint('No user logged in during initState');
    }

    if (_userId.isEmpty) {
      _userId = 'USER_${Random().nextInt(900000) + 100000}';
      debugPrint('Generated new userId: $_userId');
    }

    _storeId = _generateStoreId();
    debugPrint('Initial storeId generated: $_storeId');
  }

  /// Generates a unique store ID.
  String _generateStoreId() {
    final newStoreId = 'STORE${Random().nextInt(900000) + 100000}';
    debugPrint('Generated storeId: $newStoreId');
    return newStoreId;
  }

  /// Picks a file for document upload (image or PDF).
  Future<bool> _pickFile(String label, int documentType) async {
    try {
      debugPrint('Picking file for $label (documentType: $documentType)');
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        );

        if (result != null && result.files.single.bytes != null) {
          setState(() {
            switch (documentType) {
              case 1:
                _companyPanBytes = result.files.single.bytes;
                debugPrint('Company PAN bytes picked: ${_companyPanBytes?.length} bytes');
                break;
              case 2:
                _businessRegBytes = result.files.single.bytes;
                debugPrint('Business Registration bytes picked: ${_businessRegBytes?.length} bytes');
                break;
              case 3:
                _gstBytes = result.files.single.bytes;
                debugPrint('GST bytes picked: ${_gstBytes?.length} bytes');
                break;
            }
          });
          _showSnackBar('$label selected successfully', success: true);
          return true;
        }
      } else {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked != null) {
          setState(() {
            switch (documentType) {
              case 1:
                _companyPan = File(picked.path);
                debugPrint('Company PAN file picked: ${_companyPan?.path}');
                break;
              case 2:
                _businessReg = File(picked.path);
                debugPrint('Business Registration file picked: ${_businessReg?.path}');
                break;
              case 3:
                _gst = File(picked.path);
                debugPrint('GST file picked: ${_gst?.path}');
                break;
            }
          });
          _showSnackBar('$label selected successfully', success: true);
          return true;
        }
      }
      debugPrint('No file selected for $label');
      _showSnackBar('No file selected for $label', success: false);
      return false;
    } catch (e) {
      debugPrint('Error selecting file for $label: $e');
      _showSnackBar('Error selecting file: $e', success: false);
      return false;
    }
  }

  /// Uploads a file to Firebase Storage and returns the download URL.
  Future<String?> _uploadToStorage(String filename, int documentType) async {
    try {
      debugPrint('Uploading file to Firebase Storage: $filename (documentType: $documentType)');
      final storage = FirebaseStorage.instanceFor(bucket: 'gs://creditpump-27908');
      final storageRef = storage.ref().child(filename);

      if (kIsWeb) {
        Uint8List? bytes;
        switch (documentType) {
          case 1:
            bytes = _companyPanBytes;
            break;
          case 2:
            bytes = _businessRegBytes;
            break;
          case 3:
            bytes = _gstBytes;
            break;
        }
        if (bytes != null) {
          debugPrint('Uploading ${bytes.length} bytes to $filename');
          await storageRef.putData(bytes);
          final downloadUrl = await storageRef.getDownloadURL();
          debugPrint('File uploaded successfully. Download URL: $downloadUrl');
          return downloadUrl;
        } else {
          debugPrint('No bytes to upload for documentType $documentType');
        }
      } else {
        File? file;
        switch (documentType) {
          case 1:
            file = _companyPan;
            break;
          case 2:
            file = _businessReg;
            break;
          case 3:
            file = _gst;
            break;
        }
        if (file != null) {
          debugPrint('Uploading file ${file.path} to $filename');
          await storageRef.putFile(file);
          final downloadUrl = await storageRef.getDownloadURL();
          debugPrint('File uploaded successfully. Download URL: $downloadUrl');
          return downloadUrl;
        } else {
          debugPrint('No file to upload for documentType $documentType');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Storage Error for $filename: $e');
      return null;
    }
  }

  /// Adds a new store to the list with generated QR data.
  void _addStore() {
    final serviceName = _serviceNameController.text.isEmpty ? 'Unnamed Store' : _serviceNameController.text;
    final newStoreId = _generateStoreId();

    final qrData = {
      'merchantId': _userId,
      'storeId': newStoreId,
    };

    _stores.add({
      'storeId': newStoreId,
      'serviceName': serviceName,
      'serviceType': _serviceType,
      'qrData': qrData,
    });

    debugPrint('Added store: $serviceName (Store ID: $newStoreId, Type: $_serviceType)');

    _serviceNameController.clear();
    _storeId = _generateStoreId();

    _showSnackBar('Store added successfully', success: true);
    setState(() {});
  }

  /// Navigates to the next page or submits the registration.
  void _nextPage() {
    debugPrint('Attempting to navigate to next page from page $_currentPage');
    if (_currentPage == 0) {
      if (!_personalFormKey.currentState!.validate()) {
        debugPrint('Personal info form validation failed');
        _showSnackBar('Please fill all required fields', success: false);
        return;
      }
    } else if (_currentPage == 2) {
      if (_stores.isEmpty && _serviceNameController.text.isNotEmpty) {
        debugPrint('No stores added, adding current store');
        _addStore();
      }
      if (_stores.isEmpty) {
        debugPrint('No stores added. Aborting submission.');
        _showSnackBar('Please add at least one store', success: false);
        return;
      }
      debugPrint('Proceeding to register merchant');
      _registerMerchant();
      return;
    }

    if (_currentPage < 2) {
      setState(() {
        _currentPage++;
        debugPrint('Navigated to page: $_currentPage');
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Navigates to the previous page.
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        debugPrint('Navigated back to page: $_currentPage');
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Registers the merchant by saving data to Firestore and generating QR codes.
  Future<void> _registerMerchant() async {
    setState(() {
      _isLoading = true;
      debugPrint('Starting merchant registration process...');
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      debugPrint('Authenticated user: UID = ${user.uid}, Phone = ${user.phoneNumber}');

      final phone = user.phoneNumber!;
      debugPrint('Using raw phone number: $phone');

      // Upload documents
      debugPrint('Uploading documents to Firebase Storage...');
      if (kIsWeb ? _companyPanBytes != null : _companyPan != null) {
        _panUrl = await _uploadToStorage('kyc/$_userId/pan_${DateTime.now().millisecondsSinceEpoch}', 1);
      }
      if (kIsWeb ? _businessRegBytes != null : _businessReg != null) {
        _regUrl = await _uploadToStorage('kyc/$_userId/businessReg_${DateTime.now().millisecondsSinceEpoch}', 2);
      }
      if (kIsWeb ? _gstBytes != null : _gst != null) {
        _gstUrl = await _uploadToStorage('kyc/$_userId/gst_${DateTime.now().millisecondsSinceEpoch}', 3);
      }

      // Generate QR codes
      debugPrint('Generating QR codes for ${_stores.length} stores...');
      for (var i = 0; i < _stores.length; i++) {
        final store = _stores[i];
        debugPrint('Generating QR code for store: ${store['storeId']}');
        final qrImage = await QrPainter(
          data: store['qrData'].toString(),
          version: QrVersions.auto,
          gapless: true,
        ).toImageData(200);

        if (qrImage != null) {
          _stores[i]['qrImageBytes'] = qrImage.buffer.asUint8List();
          debugPrint('QR code generated for store: ${store['storeId']}');
        } else {
          debugPrint('Failed to generate QR code for store: ${store['storeId']}');
        }
      }

      // Save data to Firestore
      debugPrint('Saving data to Firestore...');
      final storeIds = _stores.map<String>((store) => store['storeId'] as String).toList();
      debugPrint('Store IDs to save: $storeIds');

      debugPrint('Writing to userDetails/$phone');
      await FirebaseFirestore.instance.collection('userDetails').doc(phone).set({
        'userId': _userId,
        'phoneNo': phone,
        'name': _ownerNameController.text,
        'photoUrl': user.photoURL ?? '',
        'userType': 'merchant',
        'createdAt': FieldValue.serverTimestamp(),
        'isKycVerified': false,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      debugPrint('Successfully wrote to userDetails/$phone');

      debugPrint('Writing to merchantData/$phone');
      await FirebaseFirestore.instance.collection('merchantData').doc(phone).set({
        'merchantId': phone,
        'uId': _userId,
        'phoneNo': phone,
        'stores': storeIds,
        'storeId': storeIds.first,
        'serviceType': _stores.first['serviceType'],
        'isActive': true,
        'nextSettlementAt': FieldValue.serverTimestamp(),
        'kycDocs': {
          'companyPan': _panUrl ?? '',
          'businessReg': _regUrl ?? '',
          'gst': _gstUrl ?? '',
        },
        'businessName': _businessNameController.text,
        'ownerName': _ownerNameController.text,
        'address': _addressController.text,
      });
      debugPrint('Successfully wrote to merchantData/$phone');

      debugPrint('Writing ${_stores.length} stores to stores collection...');
      for (final store in _stores) {
        debugPrint('Writing to stores/${store['storeId']}');
        await FirebaseFirestore.instance.collection('stores').doc(store['storeId']).set({
          'storeId': store['storeId'],
          'merchantId': phone,
          'serviceName': store['serviceName'],
          'serviceType': store['serviceType'],
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Successfully wrote to stores/${store['storeId']}');
      }

      debugPrint('Merchant registration completed successfully!');
      _showSnackBar('Registration successful!', success: true);
      _confettiController.play();

      setState(() {
        _isLoading = false;
      });

      _showQRCodesDialog(context);
    } catch (e) {
      debugPrint('Registration failed: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Registration failed: $e', success: false);
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.of(context).pushNamedAndRemoveUntil('/phone_login', (route) => false);
      });
    }
  }

  /// Displays a dialog with generated QR codes for stores.
  void _showQRCodesDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.1,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.teal,
                ],
              ),
              const Text(
                'Registration Successful!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your QR codes are ready. Download or share them with your customers.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF4CAF50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: _stores.length,
                  itemBuilder: (context, index) {
                    final store = _stores[index];
                    final serviceType = store['serviceType'] ?? 'fuel';
                    final storeId = store['storeId'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            store['serviceName'] ?? 'Unnamed Store',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type: $serviceType',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGlowingQR(store['qrData'].toString()),
                          const SizedBox(height: 8),
                          Text(
                            'Store ID: $storeId',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNeonButton(
                                icon: Icons.download,
                                label: 'Download',
                                onPressed: () => _downloadQRCode(store),
                              ),
                              const SizedBox(width: 10),
                              _buildNeonButton(
                                icon: Icons.share,
                                label: 'Share',
                                onPressed: () => _shareQRCode(store),
                              ),
                              if (!kIsWeb) ...[
                                const SizedBox(width: 10),
                                _buildNeonButton(
                                  icon: Icons.photo,
                                  label: 'Gallery',
                                  onPressed: () => _openGallery(store),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              _buildNeonButton(
                icon: Icons.login,
                label: 'Go to Login',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) =>  LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Downloads a QR code as an image file.
  Future<void> _downloadQRCode(Map<String, dynamic> store) async {
    try {
      final qrData = store['qrData'].toString();
      final storeName = store['serviceName'] ?? 'Unnamed Store';

      if (kIsWeb) {
        final qrImage = await QrPainter(
          data: qrData,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white,
          gapless: true,
        ).toImageData(500);

        if (qrImage != null) {
          final blob = html.Blob([qrImage.buffer.asUint8List()], 'image/png');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', '$storeName-QR.png')
            ..click();
          html.Url.revokeObjectUrl(url);
          _showSnackBar('QR code downloaded successfully', success: true);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final qrImagePath = '${tempDir.path}/$storeName-QR.png';

        final qrImage = await QrPainter(
          data: qrData,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white,
          gapless: true,
        ).toImageData(500);

        if (qrImage != null) {
          final file = File(qrImagePath);
          await file.writeAsBytes(qrImage.buffer.asUint8List());

          final result = await GallerySaver.saveImage(qrImagePath);
          if (result == true) {
            _showSnackBar('QR code saved to gallery', success: true);
          } else {
            _showSnackBar('Failed to save QR code to gallery', success: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading QR code: $e');
      _showSnackBar('Failed to download QR code: $e', success: false);
    }
  }

  /// Shares a QR code via platform-specific sharing.
  Future<void> _shareQRCode(Map<String, dynamic> store) async {
    try {
      final qrData = store['qrData'].toString();
      final storeName = store['serviceName'] ?? 'Unnamed Store';

      if (kIsWeb) {
        final qrImage = await QrPainter(
          data: qrData,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white,
          gapless: true,
        ).toImageData(200);

        if (qrImage != null) {
          final blob = html.Blob([qrImage.buffer.asUint8List()], 'image/png');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', '$storeName-QR.png')
            ..click();
          html.Url.revokeObjectUrl(url);
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final qrImagePath = '${tempDir.path}/$storeName-QR.png';

        final qrImage = await QrPainter(
          data: qrData,
          version: QrVersions.auto,
          color: Colors.black,
          emptyColor: Colors.white,
          gapless: true,
        ).toImageData(500);

        if (qrImage != null) {
          final file = File(qrImagePath);
          await file.writeAsBytes(qrImage.buffer.asUint8List());

          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Scan this QR code to access $storeName',
            subject: '$storeName QR Code',
          );
        }
      }
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      _showSnackBar('Failed to share QR code: $e', success: false);
    }
  }

  /// Saves a QR code to the device gallery (non-web platforms only).
  Future<void> _openGallery(Map<String, dynamic> store) async {
    if (kIsWeb) {
      _showSnackBar('Gallery save not available on web', success: false);
      return;
    }

    try {
      final qrData = store['qrData'].toString();
      final storeName = store['serviceName'] ?? 'Unnamed Store';

      final tempDir = await getTemporaryDirectory();
      final qrImagePath = '${tempDir.path}/$storeName-QR.png';

      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        color: Colors.black,
        emptyColor: Colors.white,
        gapless: true,
      ).toImageData(500);

      if (qrImage != null) {
        final file = File(qrImagePath);
        await file.writeAsBytes(qrImage.buffer.asUint8List());

        final result = await GallerySaver.saveImage(qrImagePath);
        if (result == true) {
          _showSnackBar('QR code saved to gallery', success: true);
        } else {
          _showSnackBar('Failed to save QR code to gallery', success: false);
        }
      }
    } catch (e) {
      debugPrint('Error saving QR code to gallery: $e');
      _showSnackBar('Failed to save QR code to gallery: $e', success: false);
    }
  }

  /// Shows a styled SnackBar for success or error messages.
  void _showSnackBar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF4CAF50) : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.backgroundDark,
                  AppColors.backgroundLight,
                ],
              ),
            ),
          ),

          // Decorative circle
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

          // Wave background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: WavePainter(animation: 0.0),
              size: Size(MediaQuery.of(context).size.width, 200),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Processing your registration...',
                    style: AppTextStyles.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primaryColor,
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'finWallet',
                              style: AppTextStyles.heading1.copyWith(
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Progress indicator
                      Row(
                        children: List.generate(3, (index) {
                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: _currentPage >= index ? Colors.white : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 20),

                      // Page title
                      Center(
                        child: Text(
                          _getPageTitle(),
                          style: AppTextStyles.heading1,
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Center(
                        child: Text(
                          _getPageSubtitle(),
                          style: AppTextStyles.body.copyWith(color: const Color(0xFF4CAF50)),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Form pages
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            ErrorBoundary(child: _buildPersonalInfoPage()),
                            ErrorBoundary(child: _buildDocumentUploadPage()),
                            ErrorBoundary(child: _buildStoreInfoPage()),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Bottom navigation
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _buildNeonButton(
                          label: _currentPage == 2 ? 'Submit' : 'Continue',
                          onPressed: _nextPage,
                          isFullWidth: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _currentPage == 2
          ? FloatingActionButton(
        backgroundColor: const Color(0xFF4CAF50),
        onPressed: _addStore,
        tooltip: 'Add another store',
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Merchant Registration',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        leading: _currentPage > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _previousPage,
        )
            : null,
      ),
    );
  }

  /// Returns the title for the current page.
  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return 'Business Information';
      case 1:
        return 'Document Upload';
      case 2:
        return 'Store Details';
      default:
        return '';
    }
  }

  /// Returns the subtitle for the current page.
  String _getPageSubtitle() {
    switch (_currentPage) {
      case 0:
        return 'Enter your business details to get started.';
      case 1:
        return 'Upload optional documents for verification.';
      case 2:
        return 'Add store details and generate QR codes.';
      default:
        return '';
    }
  }

  /// Builds the personal information input page.
  Widget _buildPersonalInfoPage() {
    debugPrint('Rendering PersonalInfoPage');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNeonTextField(
              controller: _ownerNameController,
              label: 'Owner Name',
              validator: (val) {
                debugPrint('Validating Owner Name: $val');
                return val!.isEmpty ? 'Owner name is required' : null;
              },
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _businessNameController,
              label: 'Business Name',
              validator: (val) {
                debugPrint('Validating Business Name: $val');
                return val!.isEmpty ? 'Business name is required' : null;
              },
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _addressController,
              label: 'Business Address',
              maxLines: 3,
              validator: (val) {
                debugPrint('Validating Business Address: $val');
                return val!.isEmpty ? 'Business address is required' : null;
              },
            ),
            const SizedBox(height: 16),
            _buildNeonTextField(
              controller: _phoneController,
              label: 'Phone Number (pre-filled)',
              readOnly: true,
              helperText: 'This is your registered phone number',
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the document upload page.
  Widget _buildDocumentUploadPage() {
    debugPrint('Rendering DocumentUploadPage');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload your business documents (optional)',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 20),
          _buildDocumentUploadCard(
            title: 'Company PAN Card',
            isUploaded: kIsWeb ? _companyPanBytes != null : _companyPan != null,
            onTap: () => _pickFile('Company PAN', 1),
          ),
          const SizedBox(height: 16),
          _buildDocumentUploadCard(
            title: 'Business Registration',
            isUploaded: kIsWeb ? _businessRegBytes != null : _businessReg != null,
            onTap: () => _pickFile('Business Registration', 2),
          ),
          const SizedBox(height: 16),
          _buildDocumentUploadCard(
            title: 'GST Certificate',
            isUploaded: kIsWeb ? _gstBytes != null : _gst != null,
            onTap: () => _pickFile('GST Certificate', 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Note: You can proceed without uploading documents, but verification may be required later.',
            style: AppTextStyles.body.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Builds a card for document upload.
  Widget _buildDocumentUploadCard({
    required String title,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.backgroundDark,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          Icons.description,
          color: isUploaded ? const Color(0xFF4CAF50) : Colors.grey,
        ),
        title: Text(
          title,
          style: AppTextStyles.body.copyWith(color: Colors.white, fontSize: 16),
        ),
        subtitle: Text(
          isUploaded ? 'Uploaded' : 'Not uploaded',
          style: AppTextStyles.body.copyWith(color: Colors.white70),
        ),
        trailing: _buildNeonButton(
          label: isUploaded ? 'Change' : 'Upload',
          onPressed: onTap,
        ),
        onTap: onTap,
      ),
    );
  }

  /// Builds the store information page.
  Widget _buildStoreInfoPage() {
    debugPrint('Rendering StoreInfoPage with ${_stores.length} stores');
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _storeFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNeonTextField(
                  controller: _serviceNameController,
                  label: 'Service Name (Optional)',
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _serviceType,
                  items: ['fuel', 'lubricant', 'tyre']
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.toUpperCase(),
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => _serviceType = val!),
                  decoration: InputDecoration(
                    labelText: 'Service Type',
                    labelStyle: AppTextStyles.body.copyWith(color: Colors.white),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                  ),
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                  dropdownColor: AppColors.backgroundDark,
                ),
                const SizedBox(height: 16),
                _buildNeonTextField(
                  initialValue: _storeId,
                  label: 'Store ID (auto-generated)',
                  readOnly: true,
                  helperText: 'Unique ID for this store',
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'QR Code Preview',
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildGlowingQR('{"merchantId":"$_userId","storeId":"$_storeId"}'),
                      const SizedBox(height: 10),
                      Text(
                        'Store ID: $_storeId',
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                      Text(
                        'Service: ${_serviceNameController.text.isEmpty ? 'Unnamed Store' : _serviceNameController.text}',
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                      Text(
                        'Type: $_serviceType',
                        style: AppTextStyles.body.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildNeonButton(
                            icon: Icons.download,
                            label: 'Download',
                            onPressed: () => _downloadQRCode({
                              'storeId': _storeId,
                              'serviceName': _serviceNameController.text.isEmpty
                                  ? 'Unnamed Store'
                                  : _serviceNameController.text,
                              'serviceType': _serviceType,
                              'qrData': '{"merchantId":"$_userId","storeId":"$_storeId"}',
                            }),
                          ),
                          const SizedBox(width: 10),
                          _buildNeonButton(
                            icon: Icons.share,
                            label: 'Share',
                            onPressed: () => _shareQRCode({
                              'storeId': _storeId,
                              'serviceName': _serviceNameController.text.isEmpty
                                  ? 'Unnamed Store'
                                  : _serviceNameController.text,
                              'serviceType': _serviceType,
                              'qrData': '{"merchantId":"$_userId","storeId":"$_storeId"}',
                            }),
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(width: 10),
                            _buildNeonButton(
                              icon: Icons.photo,
                              label: 'Gallery',
                              onPressed: () => _openGallery({
                                'storeId': _storeId,
                                'serviceName': _serviceNameController.text.isEmpty
                                    ? 'Unnamed Store'
                                    : _serviceNameController.text,
                                'serviceType': _serviceType,
                                'qrData': '{"merchantId":"$_userId","storeId":"$_storeId"}',
                              }),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _buildNeonButton(
                    icon: Icons.add,
                    label: 'Add This Store',
                    onPressed: _addStore,
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
          ),
          if (_stores.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                'No stores added yet. Add a store to proceed.',
                style: AppTextStyles.body.copyWith(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
          if (_stores.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Added Stores (${_stores.length})',
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ..._stores.map((store) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: AppColors.backgroundDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['serviceName'],
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service Type: ${store['serviceType'].toUpperCase()}',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Store ID: ${store['storeId']}',
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          _buildGlowingQR(store['qrData'].toString()),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNeonButton(
                                icon: Icons.download,
                                label: 'Download',
                                onPressed: () => _downloadQRCode(store),
                              ),
                              const SizedBox(width: 10),
                              _buildNeonButton(
                                icon: Icons.share,
                                label: 'Share',
                                onPressed: () => _shareQRCode(store),
                              ),
                              if (!kIsWeb) ...[
                                const SizedBox(width: 10),
                                _buildNeonButton(
                                  icon: Icons.photo,
                                  label: 'Gallery',
                                  onPressed: () => _openGallery(store),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  /// Builds a styled text field with neon design.
  Widget _buildNeonTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? helperText,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            initialValue: initialValue,
            maxLines: maxLines,
            readOnly: readOnly,
            validator: validator,
            onChanged: onChanged,
            style: AppTextStyles.body.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter $label...',
              hintStyle: AppTextStyles.body.copyWith(color: Colors.grey.shade600),
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

  /// Builds a styled neon button.
  Widget _buildNeonButton({
    IconData? icon,
    required String label,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, color: Colors.white) : const SizedBox.shrink(),
      label: Text(
        label,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        minimumSize: isFullWidth ? const Size(double.infinity, 56) : const Size(120, 46),
      ),
    );
  }

  /// Builds a glowing QR code widget.
  Widget _buildGlowingQR(String data) {
    try {
      debugPrint('Generating QR code for data: $data');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryColor.withOpacity(0.3),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 200.0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          gapless: true,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        ),
      );
    } catch (e) {
      debugPrint('Error generating QR code: $e');
      return Text(
        'Failed to generate QR code',
        style: AppTextStyles.body.copyWith(color: Colors.red.shade800, fontSize: 16),
      );
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing MerchantRegistrationScreen...');
    _ownerNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _serviceNameController.dispose();
    _upiIdController.dispose();
    _pageController.dispose();
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

/// A widget that wraps its child with error handling.
class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (e) {
          debugPrint('Error in widget: $e');
          return Center(
            child: Text(
              'Error loading page: $e',
              style: AppTextStyles.body.copyWith(color: Colors.red.shade800, fontSize: 16),
            ),
          );
        }
      },
    );
  }
}

/// A custom painter for rendering a wave background.
class WavePainter extends CustomPainter {
  final double animation;

  WavePainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (var i = 0; i < size.width.toInt(); i++) {
      final x = i.toDouble();
      final sinValue = sin((x / size.width * 4 * pi) + (animation * pi * 2));
      final y = (size.height * 0.7) + sinValue * 10;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}