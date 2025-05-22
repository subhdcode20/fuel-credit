import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import 'MerchantTransactionsScreen.dart';
import 'constants.dart';
import 'login_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
// Import the new transactions screen

/// Main merchant dashboard with a navigation drawer for Home, Transactions, Privacy, Profile, and Logout.
class MerchantHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MerchantHomeScreen({super.key, required this.userData});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen>
    with SingleTickerProviderStateMixin {
  String _name = 'Unknown';
  String _phoneNumber = 'N/A';
  String _errorMessage = '';
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initializeData();
  }

  void _initializeData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No authenticated user found. Redirecting to login...');
      setState(() {
        _errorMessage = 'Please log in to view your data.';
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
      return;
    }

    try {
      setState(() {
        _name = widget.userData['name']?.toString() ?? 'Unknown';
        _phoneNumber = _sanitizePhoneNumber(
          widget.userData['phoneNo']?.toString() ?? 'N/A',
        );
        _errorMessage = '';
      });
      debugPrint('Merchant data: Name = $_name, Phone = $_phoneNumber');
    } catch (e) {
      debugPrint('Error processing userData: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  String _sanitizePhoneNumber(String phoneNumber) {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    debugPrint('Sanitized phone number: $sanitized');
    return sanitized.isEmpty ? 'N/A' : sanitized;
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context);
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('User logged out successfully');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      debugPrint('Error logging out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log out: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(name: _name, phoneNumber: _phoneNumber),
      MerchantTransactionsScreen(phoneNumber: _phoneNumber),
      const PrivacyScreen(),
      ProfileScreen(name: _name, phoneNumber: _phoneNumber),
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
              ? 'Merchant Dashboard'
              : _selectedIndex == 1
              ? 'Transactions'
              : _selectedIndex == 2
              ? 'Privacy Policy'
              : 'Profile',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.backgroundDark, AppColors.backgroundLight],
              ),
            ),
          ),
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
          SafeArea(
            child:
                _errorMessage.isNotEmpty
                    ? Center(
                      child: Text(
                        _errorMessage,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.red.shade300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                    : FadeTransition(
                      opacity: _fadeAnimation,
                      child: screens[_selectedIndex],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryColor, AppColors.primaryDark],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.accentColor,
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : 'M',
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _name,
                    style: AppTextStyles.heading2.copyWith(color: Colors.white),
                  ),
                  Text(
                    _phoneNumber,
                    style: AppTextStyles.body.copyWith(color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.home,
              color:
                  _selectedIndex == 0
                      ? AppColors.accentColor
                      : Colors.grey[400],
            ),
            title: Text(
              'Home',
              style: AppTextStyles.body.copyWith(
                color:
                    _selectedIndex == 0 ? AppColors.accentColor : Colors.white,
              ),
            ),
            selected: _selectedIndex == 0,
            onTap: () => _onNavItemTapped(0),
          ),
          ListTile(
            leading: Icon(
              Icons.receipt_long,
              color:
                  _selectedIndex == 1
                      ? AppColors.accentColor
                      : Colors.grey[400],
            ),
            title: Text(
              'Show Transactions',
              style: AppTextStyles.body.copyWith(
                color:
                    _selectedIndex == 1 ? AppColors.accentColor : Colors.white,
              ),
            ),
            selected: _selectedIndex == 1,
            onTap: () => _onNavItemTapped(1),
          ),
          ListTile(
            leading: Icon(
              Icons.privacy_tip,
              color:
                  _selectedIndex == 2
                      ? AppColors.accentColor
                      : Colors.grey[400],
            ),
            title: Text(
              'Privacy Policy',
              style: AppTextStyles.body.copyWith(
                color:
                    _selectedIndex == 2 ? AppColors.accentColor : Colors.white,
              ),
            ),
            selected: _selectedIndex == 2,
            onTap: () => _onNavItemTapped(2),
          ),
          ListTile(
            leading: Icon(
              Icons.person,
              color:
                  _selectedIndex == 3
                      ? AppColors.accentColor
                      : Colors.grey[400],
            ),
            title: Text(
              'Profile',
              style: AppTextStyles.body.copyWith(
                color:
                    _selectedIndex == 3 ? AppColors.accentColor : Colors.white,
              ),
            ),
            selected: _selectedIndex == 3,
            onTap: () => _onNavItemTapped(3),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              'Logout',
              style: AppTextStyles.body.copyWith(color: Colors.red),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Home screen displaying a list of stores with QR codes and an option to add new stores.
class HomeScreen extends StatefulWidget {
  final String name;
  final String phoneNumber;

  const HomeScreen({super.key, required this.name, required this.phoneNumber});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _addStoreFormKey = GlobalKey<FormState>();
  final _serviceNameController = TextEditingController();
  String? _selectedServiceType;
  bool _isAddingStore = false;
  bool _subcollectionAccessDenied = false;
  final Map<String, GlobalKey> _qrKeys = {};

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    super.dispose();
  }

  void _checkAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('User not authenticated');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to continue'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      debugPrint(
        'User authenticated: uid=${user.uid}, phoneNumber=${widget.phoneNumber}, email=${user.email}',
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm:ss').format(dateTime);
  }

  String _generateStoreId() {
    final random = Random();
    final digits = List.generate(6, (_) => random.nextInt(10)).join();
    return 'STORE$digits';
  }

  String _capitalize(String? s) =>
      s != null && s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

  void _showAddStoreDialog() {
    _serviceNameController.clear();
    _selectedServiceType = null;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.backgroundLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Add New Store',
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
            ),
            content: Form(
              key: _addStoreFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _serviceNameController,
                      label: 'Service Name (Optional)',
                      validator: null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Service Type',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedServiceType,
                        hint: Text(
                          'Select Service Type',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        items:
                            ['fuel', 'lubricant', 'tyre'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(
                                  _capitalize(type),
                                  style: AppTextStyles.body.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceType = value;
                          });
                        },
                        validator:
                            (value) =>
                                value == null
                                    ? 'Service Type is required'
                                    : null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        dropdownColor: AppColors.backgroundLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                ),
              ),
              ElevatedButton(
                onPressed: _isAddingStore ? null : _addNewStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isAddingStore ? 'Adding...' : 'Add Store',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _addNewStore() async {
    if (!_addStoreFormKey.currentState!.validate()) return;

    setState(() => _isAddingStore = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storeId = _generateStoreId();
      final now = Timestamp.now();

      debugPrint(
        'Adding store: storeId=$storeId, phoneNumber=${widget.phoneNumber}, uid=${user.uid}',
      );

      final merchantDoc =
          await FirebaseFirestore.instance
              .collection('merchantData')
              .doc(widget.phoneNumber)
              .get();
      if (!merchantDoc.exists) {
        throw Exception(
          'Merchant data not found. Please complete registration.',
        );
      }
      final merchantData = merchantDoc.data()!;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('userDetails')
              .doc(widget.phoneNumber)
              .get();
      if (!userDoc.exists) {
        throw Exception(
          'User details not found. Please complete registration.',
        );
      }
      final userData = userDoc.data()!;

      final storeData = {
        'createdAt': now,
        'isActive': true,
        'merchantId': widget.phoneNumber,
        'phoneNo': widget.phoneNumber,
        'serviceName':
            _serviceNameController.text.isEmpty
                ? 'Unnamed Store'
                : _serviceNameController.text.trim(),
        'serviceType': _selectedServiceType,
        'storeId': storeId,
        'uId': userData['userId']?.toString() ?? user.uid,
        'address': merchantData['address']?.toString() ?? 'N/A',
        'businessName': merchantData['businessName']?.toString() ?? 'N/A',
        'ownerName': merchantData['ownerName']?.toString() ?? 'N/A',
        'kycDocs': {'businessReg': '', 'companyPan': '', 'gst': ''},
        'nextSettlementAt': now,
      };

      final merchantRef = FirebaseFirestore.instance
          .collection('merchantData')
          .doc(widget.phoneNumber);
      await merchantRef.update({
        'stores': FieldValue.arrayUnion([storeId]),
      });

      final storeRef = merchantRef.collection('stores').doc(storeId);
      await storeRef.set(storeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Store added successfully'),
            backgroundColor: AppColors.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error adding store: $e');
      String errorMessage = 'Failed to add store: $e';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage =
            'Permission denied. Please ensure you are logged in with the correct account.';
      } else if (e.toString().contains('Merchant data not found') ||
          e.toString().contains('User details not found')) {
        errorMessage =
            'Registration incomplete. Please complete merchant registration first.';
      } else if (e.toString().contains('network')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingStore = false);
    }
  }

  Future<Uint8List?> _captureQrCode(String storeId) async {
    try {
      final qrKey = _qrKeys[storeId];
      if (qrKey == null || qrKey.currentContext == null) {
        debugPrint('QR key not found for storeId: $storeId');
        return null;
      }

      final RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture QR code: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _shareQrCode(String storeId, String businessName) async {
    try {
      final imageBytes = await _captureQrCode(storeId);
      if (imageBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/QR_$storeId.png',
      ).writeAsBytes(imageBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Scan this QR code for $businessName (Store ID: $storeId)');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR code for $businessName shared successfully'),
          backgroundColor: AppColors.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share QR code: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view stores.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('merchantData')
              .doc(widget.phoneNumber)
              .snapshots(),
      builder: (context, merchantSnapshot) {
        if (merchantSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
            ),
          );
        }
        if (merchantSnapshot.hasError) {
          debugPrint(
            'Error fetching merchantData/${widget.phoneNumber}: ${merchantSnapshot.error}',
          );
          String errorMessage =
              'Error loading stores: ${merchantSnapshot.error}';
          if (merchantSnapshot.error.toString().contains('PERMISSION_DENIED')) {
            errorMessage =
                'Permission denied. Please log in with the correct account.';
          }
          return Center(
            child: Text(
              errorMessage,
              style: AppTextStyles.body.copyWith(color: Colors.red.shade300),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!merchantSnapshot.hasData || !merchantSnapshot.data!.exists) {
          debugPrint('No merchantData/${widget.phoneNumber} found');
          return const Center(
            child: Text(
              'No stores found. Complete merchant registration to add stores.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          );
        }

        final merchantData =
            merchantSnapshot.data!.data() as Map<String, dynamic>;
        final storeIds =
            (merchantData['stores'] as List<dynamic>?)?.cast<String>() ?? [];

        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('userDetails')
                  .doc(widget.phoneNumber)
                  .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.accentColor,
                  ),
                ),
              );
            }
            if (userSnapshot.hasError) {
              debugPrint(
                'Error fetching userDetails/${widget.phoneNumber}: ${userSnapshot.error}',
              );
              String errorMessage =
                  'Error loading user data: ${userSnapshot.error}';
              if (userSnapshot.error.toString().contains('PERMISSION_DENIED')) {
                errorMessage =
                    'Permission denied. Please log in with the correct account.';
              }
              return Center(
                child: Text(
                  errorMessage,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.red.shade300,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              debugPrint('No userDetails/${widget.phoneNumber} found');
              return const Center(
                child: Text(
                  'User data not found. Please complete registration.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              );
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userId = userData['userId']?.toString() ?? user.uid;

            return SingleChildScrollView(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryColor.withOpacity(0.3),
                            AppColors.backgroundLight.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(50),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 50),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'welcome,',
                              style: AppTextStyles.heading1.copyWith(
                                color: AppColors.accentColor,
                                fontSize: 20,
                                shadows: [
                                  Shadow(
                                    color: AppColors.primaryColor.withOpacity(
                                      0.5,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8,),
                            Text(
                              '${widget.name}!',
                              style: AppTextStyles.heading1.copyWith(
                                color: AppColors.accentColor,
                                fontSize: 20,
                                shadows: [
                                  Shadow(
                                    color: AppColors.primaryColor.withOpacity(
                                      0.5,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddStoreDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Store'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Store Dashboard',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        storeIds.isEmpty
                            ? Center(
                              child: Text(
                                'No stores available. Add a store to get started.',
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.grey[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: storeIds.length,
                              itemBuilder: (context, index) {
                                final storeId = storeIds[index];

                                if (!_qrKeys.containsKey(storeId)) {
                                  _qrKeys[storeId] = GlobalKey();
                                }

                                if (_subcollectionAccessDenied) {
                                  final businessName =
                                      merchantData['businessName'] ??
                                      'Store $storeId';
                                  final serviceType =
                                      merchantData['serviceType'] ?? 'N/A';
                                  final qrData = jsonEncode({
                                    'storeId': storeId,
                                    'userId': userId,
                                    'phoneNo': widget.phoneNumber,
                                  });

                                  return _buildStoreCard(
                                    storeId: storeId,
                                    businessName: businessName,
                                    serviceType: serviceType,
                                    qrData: qrData,
                                  );
                                }

                                return StreamBuilder<DocumentSnapshot>(
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('merchantData')
                                          .doc(widget.phoneNumber)
                                          .collection('stores')
                                          .doc(storeId)
                                          .snapshots(),
                                  builder: (context, storeSnapshot) {
                                    String businessName =
                                        merchantData['businessName'] ??
                                        'Store $storeId';
                                    String serviceType =
                                        merchantData['serviceType'] ?? 'N/A';
                                    Timestamp? createdAt;

                                    if (storeSnapshot.hasData &&
                                        storeSnapshot.data!.exists) {
                                      final storeData =
                                          storeSnapshot.data!.data()
                                              as Map<String, dynamic>;
                                      businessName =
                                          storeData['serviceName'] ??
                                          storeData['businessName'] ??
                                          businessName;
                                      serviceType =
                                          storeData['serviceType'] ??
                                          serviceType;
                                      createdAt = storeData['createdAt'];
                                    } else if (storeSnapshot.hasError) {
                                      debugPrint(
                                        'Error fetching store $storeId: ${storeSnapshot.error}',
                                      );
                                      if (storeSnapshot.error
                                          .toString()
                                          .contains('PERMISSION_DENIED')) {
                                        setState(
                                          () =>
                                              _subcollectionAccessDenied = true,
                                        );
                                      }
                                    }

                                    final qrData = jsonEncode({
                                      'storeId': storeId,
                                      'userId': userId,
                                      'phoneNo': widget.phoneNumber,
                                    });

                                    return _buildStoreCard(
                                      storeId: storeId,
                                      businessName: businessName,
                                      serviceType: serviceType,
                                      createdAt: createdAt,
                                      qrData: qrData,
                                    );
                                  },
                                );
                              },
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoreCard({
    required String storeId,
    required String businessName,
    required String serviceType,
    Timestamp? createdAt,
    required String qrData,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.2),
            AppColors.primaryDark.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: AppColors.accentColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  businessName,
                  style: AppTextStyles.heading2.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: RepaintBoundary(
              key: _qrKeys[storeId],
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 150.0,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _shareQrCode(storeId, businessName),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Store ID', storeId),
          _buildInfoItem('Service Type', serviceType),
          if (createdAt != null)
            _buildInfoItem('Created At', _formatTimestamp(createdAt)),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body.copyWith(color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryColor.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            style: AppTextStyles.body.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: AppTextStyles.body.copyWith(color: Colors.grey[600]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
