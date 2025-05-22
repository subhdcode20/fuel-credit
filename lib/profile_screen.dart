import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

/// Profile screen displaying and editing merchant details from Firestore.
class ProfileScreen extends StatefulWidget {
  final String name;
  final String phoneNumber;

  const ProfileScreen({super.key, required this.name, required this.phoneNumber});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _editFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _ownerNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _ownerNameController.dispose();
    super.dispose();
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

  /// Shows the edit profile dialog.
  void _showEditDialog(Map<String, dynamic> userData, Map<String, dynamic> merchantData) {
    _nameController.text = userData['name'] ?? widget.name;
    _businessNameController.text = merchantData['businessName'] ?? '';
    _addressController.text = merchantData['address'] ?? '';
    _ownerNameController.text = merchantData['ownerName'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Profile',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        content: Form(
          key: _editFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Name',
                  validator: (value) => value!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _businessNameController,
                  label: 'Business Name',
                  validator: (value) => value!.isEmpty ? 'Business Name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  maxLines: 2,
                  validator: (value) => value!.isEmpty ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _ownerNameController,
                  label: 'Owner Name',
                  validator: (value) => value!.isEmpty ? 'Owner Name is required' : null,
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
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _isLoading ? 'Saving...' : 'Save',
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Saves updated fields to Firestore.
  void _saveChanges() async {
    if (!_editFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Update userDetails
      await FirebaseFirestore.instance.collection('userDetails').doc(widget.phoneNumber).update({
        'name': _nameController.text.trim(),
      });

      // Update merchantData
      await FirebaseFirestore.instance.collection('merchantData').doc(widget.phoneNumber).update({
        'businessName': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          debugPrint('Error fetching userDetails: ${userSnapshot.error}');
          return Center(
            child: Text(
              'Error loading profile: ${userSnapshot.error}',
              style: AppTextStyles.body.copyWith(color: Colors.red.shade300),
            ),
          );
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(
            child: Text(
              'Profile not found',
              style: AppTextStyles.body,
            ),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;

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
              debugPrint('Error fetching merchantData: ${merchantSnapshot.error}');
              return Center(
                child: Text(
                  'Error loading merchant data: ${merchantSnapshot.error}',
                  style: AppTextStyles.body.copyWith(color: Colors.red.shade300),
                ),
              );
            }
            if (!merchantSnapshot.hasData || !merchantSnapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Merchant data not found',
                  style: AppTextStyles.body,
                ),
              );
            }

            final merchantData = merchantSnapshot.data!.data() as Map<String, dynamic>;
            final kycDocs = merchantData['kycDocs'] as Map<String, dynamic>? ?? {};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Profile',
                        style: AppTextStyles.heading1.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryColor.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showEditDialog(userData, merchantData),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your merchant account',
                    style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 24),
                  // Profile card
                  Container(
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
                        // Avatar and basic info
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.accentColor,
                              child: Text(
                                userData['name']?.toString().isNotEmpty == true
                                    ? userData['name'][0].toUpperCase()
                                    : widget.name.isNotEmpty
                                    ? widget.name[0].toUpperCase()
                                    : 'M',
                                style: AppTextStyles.heading1.copyWith(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData['name'] ?? widget.name,
                                    style: AppTextStyles.heading2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    widget.phoneNumber,
                                    style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // User Details section
                        Text(
                          'User Details',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem('Name', userData['name'] ?? widget.name),
                        _buildInfoItem('Phone Number', userData['phoneNo'] ?? widget.phoneNumber),
                        _buildInfoItem('User Type', userData['userType'] ?? 'N/A'),
                        _buildInfoItem('Created At', _formatTimestamp(userData['createdAt'])),
                        _buildInfoItem('Last Login At', _formatTimestamp(userData['lastLoginAt'])),
                        _buildInfoItem('Is Active', _formatBoolean(userData['isActive'])),
                        _buildInfoItem('KYC Verified', _formatBoolean(userData['isKycVerified'])),
                        _buildInfoItem('User ID', userData['userId'] ?? 'N/A'),
                        _buildInfoItem('Photo URL', userData['photoUrl']?.isEmpty == true ? 'None' : userData['photoUrl'] ?? 'N/A'),
                        const SizedBox(height: 24),
                        // Merchant Details section
                        Text(
                          'Merchant Details',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoItem('Business Name', merchantData['businessName'] ?? 'N/A'),
                        _buildInfoItem('Address', merchantData['address'] ?? 'N/A'),
                        _buildInfoItem('Owner Name', merchantData['ownerName'] ?? 'N/A'),
                        _buildInfoItem('Service Type', merchantData['serviceType'] ?? 'N/A'),
                        _buildInfoItem('Store ID', merchantData['storeId'] ?? 'N/A'),
                        _buildInfoItem('Stores', (merchantData['stores'] as List<dynamic>?)?.join(', ') ?? 'None'),
                        _buildInfoItem('Merchant ID', merchantData['merchantId'] ?? 'N/A'),
                        _buildInfoItem('Next Settlement At', _formatTimestamp(merchantData['nextSettlementAt'])),
                        _buildInfoItem('Is Active', _formatBoolean(merchantData['isActive'])),
                        _buildInfoItem('Business Registration', kycDocs['businessReg']?.isEmpty == true ? 'None' : kycDocs['businessReg'] ?? 'N/A'),
                        _buildInfoItem('Company PAN', kycDocs['companyPan']?.isEmpty == true ? 'None' : kycDocs['companyPan'] ?? 'N/A'),
                        _buildInfoItem('GST', kycDocs['gst']?.isEmpty == true ? 'None' : kycDocs['gst'] ?? 'N/A'),
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

  /// Builds a text field for the edit dialog.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryColor.withOpacity(0.5)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds an info item with label and value.
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