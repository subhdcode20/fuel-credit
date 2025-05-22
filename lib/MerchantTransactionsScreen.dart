
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

/// A screen displaying transactions received by the merchant.
class MerchantTransactionsScreen extends StatefulWidget {
final String phoneNumber;

const MerchantTransactionsScreen({super.key, required this.phoneNumber});

@override
State<MerchantTransactionsScreen> createState() => _MerchantTransactionsScreenState();
}

class _MerchantTransactionsScreenState extends State<MerchantTransactionsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
  }

  /// Loads recent transactions for the merchant.
  Future<void> _loadRecentTransactions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('trsData')
          .where('merchantId', isEqualTo: widget.phoneNumber)
          .get();

      final transactions = <Map<String, dynamic>>[];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
// Fetch client name for display
        final clientDoc = await FirebaseFirestore.instance
            .collection('userDetails')
            .doc(data['clientId'])
            .get();
        final clientName = clientDoc.exists
            ? clientDoc.data()!['name']?.toString() ?? 'Unknown Client'
            : 'Unknown Client';

// Handle missing or invalid createdAt
        final createdAt = data['createdAt'] as int?;
        final formattedDate = createdAt != null
            ? DateFormat('dd MMM yyyy, hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(createdAt))
            : 'Unknown date';

        transactions.add({
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'clientName': clientName,
          'createdAt': createdAt,
          'formattedDate': formattedDate,
          'status': data['status'] ?? 'unknown',
          'storeId': data['storeId'] ?? 'N/A',
          'trsId': data['trsId'] ?? 'N/A',
        });
      }

// Sort transactions by createdAt in descending order
      transactions.sort((a, b) {
        final aCreatedAt = a['createdAt'] as int? ?? 0;
        final bCreatedAt = b['createdAt'] as int? ?? 0;
        return bCreatedAt.compareTo(aCreatedAt);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load transactions: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Builds a single transaction item for display.
  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    final clientName = transaction['clientName'] as String;
    final formattedDate = transaction['formattedDate'] as String;
    final status = transaction['status'] as String;
    final storeId = transaction['storeId'] as String;

// Determine status color
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
            Icons.person,
            color: AppColors.primaryColor,
          ),
        ),
        title: Text(
          clientName,
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
            color: status == 'success' ? Colors.green[300] : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// Builds the transactions list UI.
  Widget _buildTransactionsList() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Your Transactions',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.accentColor,
                      shadows: [
                        Shadow(
                          color: AppColors.primaryColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTransactionsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

