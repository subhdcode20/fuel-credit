import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save driver data to Firestore
  Future<void> saveDriverData({
    required String name,
    required String licenseNumber,
    required String vehicleType,
    required String address,
    required String phone,
    required String bankName,
    required String accountNumber,
    required String ifsc,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final String fullPhone = phone.isNotEmpty ? phone : user.phoneNumber!;
    final String userId = user.uid;

    final userData = {
      'userId': userId,
      'phoneNo': fullPhone,
      'name': name,
      'photoUrl': user.photoURL ?? '',
      'userType': 'driver',
      'createdAt': FieldValue.serverTimestamp(),
      'isKycVerified': false,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    await _firestore.collection('userDetails').doc(fullPhone).set(userData);
    // If you want to create a driver-specific collection, do it here similarly.
  }

  // Save merchant data to Firestore according to the specified structure
  Future<void> saveMerchantData({
    required String ownerName,
    required String phone,
    required List<Map<String, dynamic>> stores,
    required String companyPanUrl,
    required String businessRegUrl,
    required String gstUrl,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final String fullPhone = phone.isNotEmpty ? phone : user.phoneNumber!;
    final String userId = user.uid;
    
    // Generate a random 6-digit store ID if not provided
    String generateStoreId() {
      return "STORE${DateTime.now().millisecondsSinceEpoch % 1000000}";
    }

    // 1. Save to userDetails collection
    // Doc ID is the user's phone number with country code
    final userDetails = {
      'userId': userId, // unique random id
      'phoneNo': fullPhone,
      'name': ownerName,
      'photoUrl': user.photoURL ?? '',
      'userType': 'merchant', // client / merchant / admin
      'createdAt': FieldValue.serverTimestamp(),
      'isKycVerified': false,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
    
    await _firestore.collection('userDetails').doc(fullPhone).set(userDetails);

    // Process store information
    if (stores.isEmpty) {
      throw Exception('At least one store is required');
    }
    
    // Extract the first store's service type for the merchant data
    final firstStore = stores.first;
    final String serviceType = firstStore['serviceType'] ?? 'fuel';
    final String storeId = firstStore['storeId'] ?? generateStoreId();
    final String qrCodeUrl = firstStore['qrCodeUrl'] ?? '';

    // 2. Save to merchantData collection
    // Doc ID is also the user's phone number with country code
    final merchantData = {
      'merchantId': fullPhone, // user full phone no. same as userDetails doc Id
      'uId': userId, // unique random Id
      'phoneNo': fullPhone,
      'stores': stores.map((store) => store['storeId']).toList(), // list of store IDs
      'storeId': storeId, // 6 digit unique Id of primary store
      'serviceType': serviceType, // fuel / lubricant / tyre
      'qrCode': qrCodeUrl, // link to unique QR for this store
      'isActive': true,
      'nextSettlementAt': FieldValue.serverTimestamp(),
      'kycDocs': {
        'companyPan': companyPanUrl,
        'businessReg': businessRegUrl,
        'gst': gstUrl,
      },
    };
    
    await _firestore.collection('merchantData').doc(fullPhone).set(merchantData);
    
    // 3. Save each store as a separate document in the stores collection
    for (var store in stores) {
      final String currentStoreId = store['storeId'] ?? generateStoreId();
      
      await _firestore.collection('stores').doc(currentStoreId).set({
        'storeId': currentStoreId,
        'merchantId': fullPhone,
        'serviceName': store['serviceName'] ?? '',
        'serviceType': store['serviceType'] ?? 'fuel',
        'qrCodeUrl': store['qrCodeUrl'] ?? '',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String phone) async {
    try {
      final docSnapshot = await _firestore.collection('userDetails').doc(phone).get();
      
      if (docSnapshot.exists) {
        return docSnapshot.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}
