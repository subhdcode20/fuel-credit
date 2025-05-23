import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'login_screen.dart';

/// A home screen for drivers, displaying personal and credit data with payment functionality.
class DriverHomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DriverHomeScreen({super.key, required this.userData});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  String _name = 'Unknown';
  String _phoneNumber = 'N/A';
  String _creditLimit = '0.00';
  String _creditBalance = '0.00';
  String _creditUsed = '0.00';
  String _errorMessage = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentTransactions = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _loadRecentTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initializes data from userData and verifies authentication.
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
        _phoneNumber = _sanitizePhoneNumber(widget.userData['phoneNo']?.toString() ?? 'N/A');

        final creditData = widget.userData['creditData'] as Map<String, dynamic>?;
        if (creditData != null) {
          _creditLimit = (creditData['creditLimit'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditBalance = (creditData['creditBal'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditUsed = (creditData['creditUsed'] as num?)?.toStringAsFixed(2) ?? '0.00';
        } else {
          _creditLimit = (widget.userData['creditLimit'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditBalance = (widget.userData['creditBal'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditUsed = (widget.userData['creditUsed'] as num?)?.toStringAsFixed(2) ?? '0.00';
        }

        _errorMessage = '';
      });
      debugPrint('Data initialized: Name = $_name, Phone = $_phoneNumber, Credit Limit = $_creditLimit, Credit Balance = $_creditBalance');
    } catch (e) {
      debugPrint('Error processing userData: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  /// Loads recent transactions for the current user
  Future<void> _loadRecentTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Query without orderBy to avoid index requirement
      final querySnapshot = await FirebaseFirestore.instance
          .collection('trsData')
          .where('clientId', isEqualTo: _phoneNumber)
          .limit(10)
          .get();

      // Collect unique merchant IDs
      final merchantIds = querySnapshot.docs
          .map((doc) => doc.data()['merchantId']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch merchant data in bulk
      Map<String, String> merchantNames = {};
      if (merchantIds.isNotEmpty) {
        final merchantQuerySnapshot = await FirebaseFirestore.instance
            .collection('userDetails')
            .where(FieldPath.documentId, whereIn: merchantIds)
            .get();
        for (var doc in merchantQuerySnapshot.docs) {
          merchantNames[doc.id] = doc.data()['name']?.toString() ?? 'Unknown Merchant';
        }
      }

      final transactions = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final merchantId = data['merchantId']?.toString();
        final merchantName = merchantId != null ? merchantNames[merchantId] ?? 'Unknown Merchant' : 'Unknown Merchant';

        final createdAt = data['createdAt'] as int?;
        final formattedDate = createdAt != null
            ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(createdAt))
            : 'Unknown date';

        transactions.add({
          'id': doc.id,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'merchantName': merchantName,
          'createdAt': createdAt,
          'formattedDate': formattedDate,
          'status': data['status']?.toString() ?? 'unknown',
          'storeId': data['storeId']?.toString() ?? 'N/A',
          'trsId': data['trsId']?.toString() ?? 'N/A',
        });
      }

      // Sort transactions by createdAt in descending order
      transactions.sort((a, b) {
        final aCreatedAt = a['createdAt'] as int? ?? 0;
        final bCreatedAt = b['createdAt'] as int? ?? 0;
        return bCreatedAt.compareTo(aCreatedAt); // Descending order
      });

      setState(() {
        _recentTransactions = transactions.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      setState(() {
        _isLoading = false;
      });
      String errorMessage = 'Failed to load transactions. Please try again.';
      if (e.toString().contains('failed-precondition')) {
        errorMessage = 'Unable to fetch transactions due to database configuration. Please try again later.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  /// Sanitizes the phone number for display.
  String _sanitizePhoneNumber(String phoneNumber) {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    debugPrint('Sanitized phone number: $sanitized');
    return sanitized.isEmpty ? 'N/A' : sanitized;
  }

  /// Initiates QR scanning and payment
  Future<void> _scanQRAndPay() async {
    try {
      final qrData = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (qrData == null) {
        debugPrint('QR scan canceled by user');
        return;
      }

      Map<String, dynamic> qrJson;
      try {
        qrJson = jsonDecode(qrData);
      } catch (e) {
        debugPrint('Invalid QR code format: $e');
        _showErrorDialog('Invalid QR code format: Not a valid JSON');
        return;
      }

      if (!qrJson.containsKey('storeId') || !qrJson.containsKey('userId') || !qrJson.containsKey('phoneNo')) {
        debugPrint('Missing required QR code fields: $qrJson');
        _showErrorDialog('Invalid QR code: Missing storeId, userId, or phoneNo');
        return;
      }

      final storeId = qrJson['storeId'] as String;
      final merchantUid = qrJson['userId'] as String;
      final merchantPhone = qrJson['phoneNo'] as String;

      final merchantDoc = await FirebaseFirestore.instance.collection('userDetails').doc(merchantPhone).get();
      if (!merchantDoc.exists) {
        debugPrint('Merchant not found for phone: $merchantPhone');
        _showErrorDialog('Merchant not found');
        return;
      }

      final merchantData = merchantDoc.data() as Map<String, dynamic>;
      final merchantName = merchantData['name']?.toString() ?? 'Unknown Merchant';

      final amount = await _showPaymentDialog(merchantName);
      if (amount == null || amount <= 0) {
        debugPrint('Payment canceled or invalid amount');
        return;
      }

      final creditBalanceNum = double.parse(_creditBalance);
      if (amount > creditBalanceNum) {
        debugPrint('Insufficient credit balance: $amount > $_creditBalance');
        _showErrorDialog('Insufficient credit balance');
        return;
      }

      await _processPayment(
        amount: amount,
        storeId: storeId,
        merchantUid: merchantUid,
        merchantPhone: merchantPhone,
        merchantName: merchantName,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} successful'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      await _refreshCreditData();
      await _loadRecentTransactions();
    } catch (e) {
      debugPrint('Error in QR scan and payment: $e');
      _showErrorDialog('Payment failed: $e');
    }
  }

  /// Shows a dialog to enter payment amount
  Future<double?> _showPaymentDialog(String merchantName) async {
    final amountController = TextEditingController();
    double? result;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Make Payment',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Merchant: $merchantName',
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Available Credit: ₹$_creditBalance',
              style: AppTextStyles.body.copyWith(color: Colors.green[300]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.currency_rupee, color: AppColors.primaryColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.primaryColor),
                ),
                filled: true,
                fillColor: AppColors.backgroundDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amountText = amountController.text.trim();
              if (amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an amount')),
                );
                return;
              }

              try {
                final amount = double.parse(amountText);
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Amount must be greater than 0')),
                  );
                  return;
                }
                result = amount;
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Pay'),
          ),
        ],
      ),
    );

    amountController.dispose();
    return result;
  }

  /// Processes the payment transaction
  Future<void> _processPayment({
    required double amount,
    required String storeId,
    required String merchantUid,
    required String merchantPhone,
    required String merchantName,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final trsId = const Uuid().v4();
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    try {
      final driverRef = FirebaseFirestore.instance.collection('clientCreditData').doc(_phoneNumber);
      batch.update(driverRef, {
        'creditBal': FieldValue.increment(-amount),
        'creditUsed': FieldValue.increment(amount),
      });

      final merchantRef = FirebaseFirestore.instance.collection('merchantData').doc(merchantPhone);
      batch.update(merchantRef, {
        'currentBalance': FieldValue.increment(amount),
      });

      final transactionRef = FirebaseFirestore.instance.collection('trsData').doc();
      batch.set(transactionRef, {
        'trsId': trsId,
        'merchantId': merchantPhone,
        'storeId': storeId,
        'clientId': _phoneNumber,
        'amount': amount,
        'createdAt': createdAt,
        'status': 'success',
        'isReported': false,
      });

      await batch.commit();
      debugPrint('Payment processed: trsId=$trsId, amount=$amount');
    } catch (e) {
      debugPrint('Error processing payment: $e');
      final failedTransactionRef = FirebaseFirestore.instance.collection('trsData').doc();
      await failedTransactionRef.set({
        'trsId': trsId,
        'merchantId': merchantPhone,
        'storeId': storeId,
        'clientId': _phoneNumber,
        'amount': amount,
        'createdAt': createdAt,
        'status': 'failed',
        'isReported': false,
      });
      throw Exception('Failed to process payment: $e');
    }
  }

  /// Refreshes credit data from Firestore
  Future<void> _refreshCreditData() async {
    try {
      final creditDoc = await FirebaseFirestore.instance.collection('clientCreditData').doc(_phoneNumber).get();

      if (creditDoc.exists) {
        final data = creditDoc.data() as Map<String, dynamic>;
        setState(() {
          _creditLimit = (data['creditLimit'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditBalance = (data['creditBal'] as num?)?.toStringAsFixed(2) ?? '0.00';
          _creditUsed = (data['creditUsed'] as num?)?.toStringAsFixed(2) ?? '0.00';
        });
        debugPrint('Credit data refreshed: limit=$_creditLimit, balance=$_creditBalance, used=$_creditUsed');
      }
    } catch (e) {
      debugPrint('Error refreshing credit data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh credit data: $e')),
      );
    }
  }

  /// Shows an error dialog with the given message
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Error',
          style: AppTextStyles.heading2.copyWith(color: Colors.red[300]),
        ),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: AppColors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Driver Dashboard',
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _refreshCreditData();
              _loadRecentTransactions();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: Stack(
        children: [
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 100,
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
          SafeArea(
            child: _errorMessage.isNotEmpty
                ? Center(
              child: Text(
                _errorMessage,
                style: AppTextStyles.body.copyWith(color: Colors.red.shade300),
                textAlign: TextAlign.center,
              ),
            )
                : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanQRAndPay,
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan & Pay'),
      ),
    );
  }

  /// Builds the drawer for navigation
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.backgroundLight,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryColor, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _name,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _phoneNumber,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard, color: AppColors.primaryColor),
            title: Text(
              'Dashboard',
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            onTap: () {
              _tabController.animateTo(0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.receipt_long, color: AppColors.primaryColor),
            title: Text(
              'Transactions',
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            onTap: () {
              _tabController.animateTo(1);
              Navigator.pop(context);
            },
          ),
          const Divider(color: Colors.grey),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[300]),
            title: Text(
              'Logout',
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $_name!',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: 8),
          Text(
            'Your driver dashboard',
            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          _buildCreditCard(),
          const SizedBox(height: 24),
          _buildInfoCard(
            title: 'Personal Details',
            icon: Icons.person_outline,
            items: [
              _buildInfoItem('Name', _name),
              _buildInfoItem('Phone', _phoneNumber),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentTransactions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: AppTextStyles.heading2.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () {
                      _tabController.animateTo(1);
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(color: AppColors.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            ..._recentTransactions.take(3).map((transaction) => _buildTransactionItem(transaction)),
          ],
        ],
      ),
    );
  }

  Widget _buildCreditCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Credit Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Icon(
                Icons.account_balance_wallet,
                color: Colors.white.withOpacity(0.8),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹$_creditBalance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCreditInfoColumn('Credit Limit', '₹$_creditLimit'),
              _buildCreditInfoColumn('Credit Used', '₹$_creditUsed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return _isLoading
        ? Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
      ),
    )
        : _recentTransactions.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    )
        : RefreshIndicator(
      onRefresh: _loadRecentTransactions,
      color: AppColors.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionItem(_recentTransactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final merchantName = transaction['merchantName'] as String;
    final formattedDate = transaction['formattedDate'] as String;
    final status = transaction['status'] as String;
    final storeId = transaction['storeId'] as String;

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'success':
        statusColor = Colors.green[300]!;
        break;
      case 'failed':
        statusColor = Colors.red[300]!;
        break;
      default:
        statusColor = Colors.grey[400]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.backgroundLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor.withOpacity(0.2),
          child: Icon(
            Icons.store,
            color: AppColors.primaryColor,
          ),
        ),
        title: Text(
          merchantName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Store: $storeId • Status: $status',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: status == 'success' ? Colors.red[300] : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppColors.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.7);
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldDelegate) => false;
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              if (_isProcessing) return;
              _isProcessing = true;
              final String? qrData = capture.barcodes.first.rawValue;
              if (qrData != null) {
                Navigator.pop(context, qrData);
              }
              _isProcessing = false;
            },
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => controller.toggleTorch(),
                icon: const Icon(Icons.flashlight_on),
                label: const Text('Toggle Flash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}