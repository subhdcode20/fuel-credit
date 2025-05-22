import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'constants.dart';

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

  // GlobalKey for capturing QR code
  final Map<String, GlobalKey> _qrKeys = {};

  get result => null;

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

  /// Checks if the user is authenticated.
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      debugPrint('User authenticated: uid=${user.uid}, phoneNumber=${widget.phoneNumber}, email=${user.email}');
    }
  }

  /// Formats a Firestore Timestamp to a readable string.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, HH:mm:ss').format(dateTime);
  }

  /// Formats a boolean value as Yes/No.
  String _formatBoolean(bool? value) {
    return value == true ? 'Yes' : 'No';
  }

  /// Generates a unique store ID (e.g., STORE859265).
  String _generateStoreId() {
    final random = Random();
    final digits = List.generate(6, (_) => random.nextInt(10)).join();
    return 'STORE$digits';
  }

  /// Capitalizes the first letter of a string.
  String _capitalize(String? s) => s != null && s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '';

  /// Shows the add store dialog.
  void _showAddStoreDialog() {
    _serviceNameController.clear();
    _selectedServiceType = null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedServiceType,
                    hint: Text(
                      'Select Service Type',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[600]),
                    ),
                    items: ['fuel', 'lubricant', 'tyre'].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          _capitalize(type),
                          style: AppTextStyles.body.copyWith(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedServiceType = value;
                      });
                    },
                    validator: (value) => value == null ? 'Service Type is required' : null,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  /// Adds a new store to Firestore.
  void _addNewStore() async {
    if (!_addStoreFormKey.currentState!.validate()) return;

    setState(() => _isAddingStore = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storeId = _generateStoreId();
      final now = Timestamp.now();

      debugPrint('Adding store: storeId=$storeId, phoneNumber=${widget.phoneNumber}, uid=${user.uid}');

      final merchantDoc = await FirebaseFirestore.instance.collection('merchantData').doc(widget.phoneNumber).get();
      if (!merchantDoc.exists) {
        throw Exception('Merchant data not found. Please complete registration.');
      }
      final merchantData = merchantDoc.data()!;

      final userDoc = await FirebaseFirestore.instance.collection('userDetails').doc(widget.phoneNumber).get();
      if (!userDoc.exists) {
        throw Exception('User details not found. Please complete registration.');
      }
      final userData = userDoc.data()!;

      final storeData = {
        'createdAt': now,
        'isActive': true,
        'merchantId': widget.phoneNumber,
        'phoneNo': widget.phoneNumber,
        'serviceName': _serviceNameController.text.isEmpty ? 'Unnamed Store' : _serviceNameController.text.trim(),
        'serviceType': _selectedServiceType,
        'storeId': storeId,
        'uId': userData['userId']?.toString() ?? user.uid,
        'address': merchantData['address']?.toString() ?? 'N/A',
        'businessName': merchantData['businessName']?.toString() ?? 'N/A',
        'ownerName': merchantData['ownerName']?.toString() ?? 'N/A',
        'kycDocs': {
          'businessReg': '',
          'companyPan': '',
          'gst': '',
        },
        'nextSettlementAt': now,
      };

      final merchantRef = FirebaseFirestore.instance.collection('merchantData').doc(widget.phoneNumber);
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error adding store: $e');
      String errorMessage = 'Failed to add store: $e';
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please ensure you are logged in with the correct account.';
      } else if (e.toString().contains('Merchant data not found') || e.toString().contains('User details not found')) {
        errorMessage = 'Registration incomplete. Please complete merchant registration first.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingStore = false);
    }
  }

  /// Captures the QR code as an image.
  Future<Uint8List?> _captureQrCode(String storeId) async {
    try {
      final qrKey = _qrKeys[storeId];
      if (qrKey == null || qrKey.currentContext == null) {
        debugPrint('QR key not found for storeId: $storeId');
        return null;
      }

      final RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture QR code: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return null;
    }
  }

  /// Downloads the QR code to the gallery.
  Future<void> _downloadQrCode(String storeId, String businessName) async {
    try {
      final imageBytes = await _captureQrCode(storeId);
      if (imageBytes == null) return;

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code for $businessName saved to gallery'),
            backgroundColor: AppColors.accentColor,
          ),
        );
      } else {
        throw Exception('Failed to save QR code');
      }
    } catch (e) {
      debugPrint('Error downloading QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download QR code: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  /// Shares the QR code.
  Future<void> _shareQrCode(String storeId, String businessName) async {
    try {
      final imageBytes = await _captureQrCode(storeId);
      if (imageBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/QR_$storeId.png').writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code for $businessName (Store ID: $storeId)',
      );
    } catch (e) {
      debugPrint('Error sharing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share QR code: $e'),
          backgroundColor: Colors.red.shade800,
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

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    // Define responsive sizes
    final padding = isSmallScreen ? 8.0 : isMediumScreen ? 12.0 : 16.0;
    final headerFontSize = isSmallScreen ? 16.0 : isMediumScreen ? 20.0 : 24.0;
    final bodyFontSize = isSmallScreen ? 10.0 : isMediumScreen ? 12.0 : 14.0;
    final buttonFontSize = isSmallScreen ? 10.0 : isMediumScreen ? 12.0 : 14.0;
    final gradientHeight = isSmallScreen ? 120.0 : isMediumScreen ? 140.0 : 160.0;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('merchantData').doc(widget.phoneNumber).snapshots(),
      builder: (context, merchantSnapshot) {
        if (merchantSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
            ),
          );
        }
        if (merchantSnapshot.hasError) {
          debugPrint('Error fetching merchantData/${widget.phoneNumber}: ${merchantSnapshot.error}');
          String errorMessage = 'Error loading stores: ${merchantSnapshot.error}';
          if (merchantSnapshot.error.toString().contains('PERMISSION_DENIED')) {
            errorMessage = 'Permission denied. Please log in with the correct account.';
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

        final merchantData = merchantSnapshot.data!.data() as Map<String, dynamic>;
        final storeIds = (merchantData['stores'] as List<dynamic>?)?.cast<String>() ?? [];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('userDetails').doc(widget.phoneNumber).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentColor),
                ),
              );
            }
            if (userSnapshot.hasError) {
              debugPrint('Error fetching userDetails/${widget.phoneNumber}: ${userSnapshot.error}');
              String errorMessage = 'Error loading user data: ${userSnapshot.error}';
              if (userSnapshot.error.toString().contains('PERMISSION_DENIED')) {
                errorMessage = 'Permission denied. Please log in with the correct account.';
              }
              return Center(
                child: Text(
                  errorMessage,
                  style: AppTextStyles.body.copyWith(color: Colors.red.shade300),
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
                      height: gradientHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primaryColor.withOpacity(0.3),
                            AppColors.backgroundLight.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(50)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: isSmallScreen ? 30 : 40),
                        // Welcome header and Add Store button
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.name}!',
                                  style: AppTextStyles.heading1.copyWith(
                                    color: AppColors.accentColor,
                                    fontSize: 8,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.primaryColor.withOpacity(0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: constraints.maxWidth,
                                  child: ElevatedButton.icon(
                                    onPressed: _showAddStoreDialog,
                                    icon: Icon(Icons.add, size: buttonFontSize),
                                    label: Text('Add Store'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accentColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 12 : 16,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                      textStyle: TextStyle(
                                        fontSize: buttonFontSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your Store Dashboard',
                          style: AppTextStyles.body.copyWith(
                            color: Colors.grey[400],
                            fontSize: bodyFontSize,
                          ),
                        ),
                        const SizedBox(height: 12),
                        storeIds.isEmpty
                            ? Center(
                          child: Text(
                            'No stores available. Add a store to get started.',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.grey[400],
                              fontSize: bodyFontSize,
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
                              final businessName = merchantData['businessName'] ?? 'Store $storeId';
                              final serviceType = merchantData['serviceType'] ?? 'N/A';
                              final address = merchantData['address'] ?? 'N/A';
                              final ownerName = merchantData['ownerName'] ?? 'N/A';
                              final isActive = merchantData['isActive'] ?? false;
                              final kycDocs = merchantData['kycDocs'] ?? {};
                              final nextSettlementAt = merchantData['nextSettlementAt'];

                              final qrData = jsonEncode({
                                'storeId': storeId,
                                'userId': userId,
                                'phoneNo': widget.phoneNumber,
                              });

                              return _buildStoreCard(
                                storeId: storeId,
                                businessName: businessName,
                                serviceType: serviceType,
                                address: address,
                                ownerName: ownerName,
                                isActive: isActive,
                                kycDocs: kycDocs,
                                nextSettlementAt: nextSettlementAt,
                                qrData: qrData,
                              );
                            }

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('merchantData')
                                  .doc(widget.phoneNumber)
                                  .collection('stores')
                                  .doc(storeId)
                                  .snapshots(),
                              builder: (context, storeSnapshot) {
                                String businessName = merchantData['businessName'] ?? 'Store $storeId';
                                String serviceType = merchantData['serviceType'] ?? 'N/A';
                                String address = merchantData['address'] ?? 'N/A';
                                String ownerName = merchantData['ownerName'] ?? 'N/A';
                                bool isActive = merchantData['isActive'] ?? false;
                                Map<String, dynamic> kycDocs = merchantData['kycDocs'] ?? {};
                                Timestamp? createdAt;
                                Timestamp? nextSettlementAt = merchantData['nextSettlementAt'];

                                if (storeSnapshot.hasData && storeSnapshot.data!.exists) {
                                  final storeData = storeSnapshot.data!.data() as Map<String, dynamic>;
                                  businessName = storeData['serviceName'] ?? storeData['businessName'] ?? businessName;
                                  serviceType = storeData['serviceType'] ?? serviceType;
                                  address = storeData['address'] ?? address;
                                  ownerName = storeData['ownerName'] ?? ownerName;
                                  isActive = storeData['isActive'] ?? isActive;
                                  kycDocs = storeData['kycDocs'] ?? kycDocs;
                                  createdAt = storeData['createdAt'];
                                  nextSettlementAt = storeData['nextSettlementAt'] ?? nextSettlementAt;
                                } else if (storeSnapshot.hasError) {
                                  debugPrint('Error fetching store $storeId: ${storeSnapshot.error}');
                                  if (storeSnapshot.error.toString().contains('PERMISSION_DENIED')) {
                                    setState(() => _subcollectionAccessDenied = true);
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
                                  address: address,
                                  ownerName: ownerName,
                                  isActive: isActive,
                                  kycDocs: kycDocs,
                                  createdAt: createdAt,
                                  nextSettlementAt: nextSettlementAt,
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

  /// Builds a store card widget.
  Widget _buildStoreCard({
    required String storeId,
    required String businessName,
    required String serviceType,
    required String address,
    required String ownerName,
    required bool isActive,
    required Map<String, dynamic> kycDocs,
    Timestamp? createdAt,
    Timestamp? nextSettlementAt,
    required String qrData,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
              Icon(Icons.store, color: AppColors.accentColor, size: isSmallScreen ? 24 : 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  businessName,
                  style: AppTextStyles.heading2.copyWith(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18 : 20,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                size: isSmallScreen ? 120 : 150,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _shareQrCode(storeId, businessName),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 12,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  textStyle: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('Store ID', storeId, isSmallScreen),
          _buildInfoItem('Service Type', serviceType, isSmallScreen),
        ],
      ),
    );
  }

  /// Builds a text field for the add store dialog.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
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
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontSize: isSmallScreen ? 14 : 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter $label',
              hintStyle: AppTextStyles.body.copyWith(
                color: Colors.grey[600],
                fontSize: isSmallScreen ? 14 : 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an info item with label and value.
  Widget _buildInfoItem(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: Colors.grey[400],
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}