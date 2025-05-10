import 'package:craditapp/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'constants.dart';

class MerchantHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const MerchantHomeScreen({Key? key, this.userData}) : super(key: key);

  @override
  _MerchantHomeScreenState createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> storesList = [];
  Map<String, dynamic> merchantData = {};
  Map<String, dynamic> userData = {};
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      // Check if userData was passed to the widget
      if (widget.userData != null && widget.userData!.isNotEmpty) {
        userData = widget.userData!;
        
        // Use the phone number from userData to fetch merchant data
        String phoneNumber = userData['phoneNo'] ?? "";
        
        final merchantDoc = await FirebaseFirestore.instance
            .collection('merchantData')
            .doc(phoneNumber)
            .get();
            
        if (!merchantDoc.exists) {
          // Try with userId if phone number doesn't work
          final merchantQuery = await FirebaseFirestore.instance
              .collection('merchantData')
              .where('uId', isEqualTo: userData['userId'])
              .limit(1)
              .get();
              
          if (merchantQuery.docs.isEmpty) {
            setState(() {
              isLoading = false;
            });
            Fluttertoast.showToast(msg: "Merchant data not found");
            return;
          }
          
          merchantData = merchantQuery.docs.first.data();
        } else {
          merchantData = merchantDoc.data() ?? {};
        }
        
        // Load store data after merchant data is loaded
        await _loadStoreData();
        return;
      }
      
      // If no userData was passed, continue with existing code to fetch from Firebase
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: "User not logged in");
        return;
      }
      
      String userId = user.uid;
      String phoneNumber = user.phoneNumber ?? "";
      
      // Fetch user data from userDetails collection
      final userDoc = await FirebaseFirestore.instance
          .collection('userDetails')
          .doc(userId)
          .get();
          
      if (!userDoc.exists) {
        // Try to fetch by phone number if userId doesn't work
        final userQuery = await FirebaseFirestore.instance
            .collection('userDetails')
            .where('phoneNo', isEqualTo: phoneNumber)
            .limit(1)
            .get();
            
        if (userQuery.docs.isEmpty) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: "User data not found");
          return;
        }
        
        userData = userQuery.docs.first.data();
      } else {
        userData = userDoc.data() ?? {};
      }
      
      // Now fetch merchant data using phone number
      phoneNumber = userData['phoneNo'] ?? phoneNumber;
      
      final merchantDoc = await FirebaseFirestore.instance
          .collection('merchantData')
          .doc(phoneNumber)
          .get();
          
      if (!merchantDoc.exists) {
        // Try with userId if phone number doesn't work
        final merchantQuery = await FirebaseFirestore.instance
            .collection('merchantData')
            .where('uId', isEqualTo: userId)
            .limit(1)
            .get();
            
        if (merchantQuery.docs.isEmpty) {
          setState(() {
            isLoading = false;
          });
          Fluttertoast.showToast(msg: "Merchant data not found");
          return;
        }
        
        merchantData = merchantQuery.docs.first.data();
      } else {
        merchantData = merchantDoc.data() ?? {};
      }
      
      // Load store data after merchant data is loaded
      await _loadStoreData();
      
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: "Failed to load user data: $e");
    }
  }
  
  Future<void> _loadStoreData() async {
    try {
      final List<dynamic> storeIds = merchantData['stores'] ?? [];
      
      if (storeIds.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      List<Map<String, dynamic>> stores = [];
      
      // For each store ID, create a store object with QR data
      for (String storeId in storeIds) {
        Map<String, dynamic> storeData = {
          'storeId': storeId,
          'serviceName': 'Store ${stores.length + 1}',
          'serviceType': merchantData['serviceType'] ?? 'fuel',
          'isActive': merchantData['isActive'] ?? true,
        };
        
        stores.add(storeData);
      }
      
      setState(() {
        storesList = stores;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading store data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _shareQRCode(Map<String, dynamic> store) async {
    try {
      final qrData = {
        'merchantId': merchantData['merchantId'] ?? merchantData['phoneNo'],
        'storeId': store['storeId'],
      };
      
      final qrImage = await QrPainter(
        data: qrData.toString(),
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      ).toImageData(300);
      
      if (qrImage == null) {
        Fluttertoast.showToast(msg: "Failed to generate QR code");
        return;
      }
      
      final bytes = qrImage.buffer.asUint8List();
      
      if (kIsWeb) {
        Fluttertoast.showToast(msg: "Sharing not supported on web");
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${store['storeId']}_qrcode.png');
        await file.writeAsBytes(bytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'QR Code for ${store['serviceName']} (Store ID: ${store['storeId']})',
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to share QR code: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // Background elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryDark.withOpacity(0.15),
              ),
            ),
          ),
          // Wave decoration at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: WaveClipper(),
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
          // Main content
          SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SafeArea(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accentColor))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Merchant Dashboard",
                                style: AppTextStyles.heading1,
                              ),
                              IconButton(
                                icon: Icon(Icons.logout, color: Colors.white),
                                onPressed: () {
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(),));
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        _buildInfoCard(
                          title: 'Business Information',
                          children: [
                            _buildInfoRow('Business Name', merchantData['businessName'] ?? 'Not Available'),
                            _buildInfoRow('Owner Name', merchantData['ownerName'] ?? userData['name'] ?? 'Not Available'),
                            _buildInfoRow('Address', merchantData['address'] ?? 'Not Available'),
                            _buildInfoRow('Service Type', merchantData['serviceType'] ?? 'Not Available'),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'KYC Documents',
                          children: [
                            _buildInfoRow('Company PAN', merchantData['kycDocs']?['companyPan'] != null &&
                                                      merchantData['kycDocs']['companyPan'].isNotEmpty ?
                                                      'Uploaded' : 'Not Uploaded'),
                            _buildInfoRow('Business Registration', merchantData['kycDocs']?['businessReg'] != null &&
                                                                merchantData['kycDocs']['businessReg'].isNotEmpty ?
                                                                'Uploaded' : 'Not Uploaded'),
                            _buildInfoRow('GST Certificate', merchantData['kycDocs']?['gst'] != null &&
                                                          merchantData['kycDocs']['gst'].isNotEmpty ?
                                                          'Uploaded' : 'Not Uploaded'),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Account Status',
                          children: [
                            _buildInfoRow('Active Status', merchantData['isActive'] == true ? 'Active' : 'Inactive'),
                            _buildInfoRow('KYC Verified', userData['isKycVerified'] == true ? 'Verified' : 'Pending'),
                            _buildInfoRow('Next Settlement', merchantData['nextSettlementAt'] != null ?
                                                          _formatTimestamp(merchantData['nextSettlementAt']) : 'Not Scheduled'),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Add this wave clipper class at the end of the file
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 40);
    
    var firstControlPoint = Offset(size.width / 4, size.height);
    var firstEndPoint = Offset(size.width / 2.25, size.height - 30);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy,
        firstEndPoint.dx, firstEndPoint.dy);
    
    var secondControlPoint = Offset(size.width - (size.width / 3.25), size.height - 65);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy,
        secondEndPoint.dx, secondEndPoint.dy);
    
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
  return 'Not Available';
}

Widget _buildInfoCard({required String title, required List<Widget> children}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          Divider(),
          ...children,
        ],
      ),
    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }