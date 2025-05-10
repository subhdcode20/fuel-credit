import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:craditapp/constants.dart';
import 'package:craditapp/login_screen.dart';
import 'package:craditapp/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class DriverRegistrationScreen extends StatefulWidget {
  final String? phoneNumber;
  
  const DriverRegistrationScreen({Key? key, this.phoneNumber}) : super(key: key);
  
  @override
  _DriverRegistrationScreenState createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool isLoading = false;
  
  // Form controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final bankNameController = TextEditingController();
  final accountNumberController = TextEditingController();
  final ifscController = TextEditingController();
  
  // Form keys for validation
  final _personalFormKey = GlobalKey<FormState>();
  final _kycFormKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  
  // Document files
  File? panCard;
  File? businessReg;
  File? aadharCard;
  
  // Web document bytes
  Uint8List? panCardBytes;
  Uint8List? businessRegBytes;
  Uint8List? aadharCardBytes;
  
  @override
  void initState() {
    super.initState();
    // Pre-fill phone number if available
    if (widget.phoneNumber != null) {
      phoneController.text = widget.phoneNumber!;
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    emailController.dispose();
    addressController.dispose();
    phoneController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    ifscController.dispose();
    super.dispose();
  }
  
  void nextPage() {
    if (_currentPage == 0 && !_personalFormKey.currentState!.validate()) return;
    if (_currentPage == 1) {
      // Check if at least PAN and Aadhar are uploaded
      if ((kIsWeb ? (panCardBytes == null || aadharCardBytes == null) : (panCard == null || aadharCard == null))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PAN and Aadhar documents are required"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
      });
    } else {
      submitForm();
    }
  }
  
  void previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }
  
  Future<void> _pickDocument(int docType) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile != null) {
        if (kIsWeb) {
          // For web
          final bytes = await pickedFile.readAsBytes();
          setState(() {
            switch (docType) {
              case 1: // PAN
                panCardBytes = bytes;
                break;
              case 2: // Business Reg
                businessRegBytes = bytes;
                break;
              case 3: // Aadhar
                aadharCardBytes = bytes;
                break;
            }
          });
        } else {
          // For mobile
          setState(() {
            switch (docType) {
              case 1: // PAN
                panCard = File(pickedFile.path);
                break;
              case 2: // Business Reg
                businessReg = File(pickedFile.path);
                break;
              case 3: // Aadhar
                aadharCard = File(pickedFile.path);
                break;
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking document: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<String?> _uploadToStorage(String storagePath, int docType) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask;
      
      if (kIsWeb) {
        // For web
        Uint8List? bytes;
        switch (docType) {
          case 1: // PAN
            bytes = panCardBytes;
            break;
          case 2: // Business Reg
            bytes = businessRegBytes;
            break;
          case 3: // Aadhar
            bytes = aadharCardBytes;
            break;
        }
        
        if (bytes != null) {
          uploadTask = storageRef.putData(bytes);
          await uploadTask;
          return await storageRef.getDownloadURL();
        }
      } else {
        // For mobile
        File? file;
        switch (docType) {
          case 1: // PAN
            file = panCard;
            break;
          case 2: // Business Reg
            file = businessReg;
            break;
          case 3: // Aadhar
            file = aadharCard;
            break;
        }
        
        if (file != null) {
          uploadTask = storageRef.putFile(file);
          await uploadTask;
          return await storageRef.getDownloadURL();
        }
      }
      
      return null;
    } catch (e) {
      print("Error uploading document: $e");
      return null;
    }
  }
  
  Future<void> submitForm() async {
    if (!_bankFormKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      // Generate unique user ID
      final userId = Uuid().v4();
      final phone = phoneController.text.trim();
      
      // Upload documents to Firebase Storage
      String? panUrl, regUrl, aadharUrl;
      
      if (kIsWeb ? panCardBytes != null : panCard != null) {
        panUrl = await _uploadToStorage('kyc/$userId/pan_${DateTime.now().millisecondsSinceEpoch}', 1);
      }
      
      if (kIsWeb ? businessRegBytes != null : businessReg != null) {
        regUrl = await _uploadToStorage('kyc/$userId/businessReg_${DateTime.now().millisecondsSinceEpoch}', 2);
      }
      
      if (kIsWeb ? aadharCardBytes != null : aadharCard != null) {
        aadharUrl = await _uploadToStorage('kyc/$userId/aadhar_${DateTime.now().millisecondsSinceEpoch}', 3);
      }
      
      // Save to userDetails collection
      await FirebaseFirestore.instance.collection('userDetails').doc(phone).set({
        'userId': userId,
        'phoneNo': phone,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'photoUrl': '',
        'userType': 'client',
        'createdAt': FieldValue.serverTimestamp(),
        'isKycVerified': false,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      
      // Save to clientCreditData collection
      await FirebaseFirestore.instance.collection('clientCreditData').doc(phone).set({
        'clientId': phone,
        'uId': userId,
        'phoneNo': phone,
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
        },
        'bankDetails': {
          'bankName': bankNameController.text.trim(),
          'accountNumber': accountNumberController.text.trim(),
          'ifsc': ifscController.text.trim(),
        },
        'address': addressController.text.trim(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Registration successful!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      // Navigate to login screen after successful registration
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Driver Registration"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _currentPage > 0 ? previousPage() : Navigator.pop(context),
        ),
      ),
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
          Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentPage >= index 
                              ? AppColors.primaryColor 
                              : AppColors.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              
              // Page title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getPageTitle(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 8),
              
              // Page subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _getPageSubtitle(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Form pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
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
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? SizedBox(
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
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
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
            ],
          ),
        ],
      ),
    );
  }
  
  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return "Personal Information";
      case 1:
        return "KYC Documents";
      case 2:
        return "Bank Information";
      default:
        return "";
    }
  }
  
  String _getPageSubtitle() {
    switch (_currentPage) {
      case 0:
        return "Please provide your personal details";
      case 1:
        return "Upload your identification documents";
      case 2:
        return "Add your bank details for receiving credits";
      default:
        return "";
    }
  }
  
  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _personalFormKey,
        child: Column(
          children: [
            _buildInputField(
              controller: nameController,
              label: "Full Name",
              icon: Icons.person_outline,
              validator: (value) => value!.isEmpty ? 'Name is required' : null,
            ),
            SizedBox(height: 16),
            _buildInputField(
              controller: phoneController,
              label: "Phone Number",
              icon: Icons.phone_android,
              keyboardType: TextInputType.phone,
              enabled: widget.phoneNumber == null, // Disable if pre-filled
              validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
            ),
            SizedBox(height: 16),
            _buildInputField(
              controller: emailController,
              label: "Email Address",
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
            SizedBox(height: 16),
            _buildInputField(
              controller: addressController,
              label: "Address",
              icon: Icons.home_outlined,
              maxLines: 3,
              validator: (value) => value!.isEmpty ? 'Address is required' : null,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildKycDocumentsPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _kycFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDocumentUploadCard(
              title: "PAN Card",
              subtitle: "Upload your PAN card",
              icon: Icons.credit_card,
              hasFile: kIsWeb ? panCardBytes != null : panCard != null,
              onTap: () => _pickDocument(1),
              required: true,
            ),
            SizedBox(height: 16),
            _buildDocumentUploadCard(
              title: "Business Registration",
              subtitle: "Upload your business registration document",
              icon: Icons.business,
              hasFile: kIsWeb ? businessRegBytes != null : businessReg != null,
              onTap: () => _pickDocument(2),
              required: false,
            ),
            SizedBox(height: 16),
            _buildDocumentUploadCard(
              title: "Aadhar Card",
              subtitle: "Upload your Aadhar card",
              icon: Icons.badge,
              hasFile: kIsWeb ? aadharCardBytes != null : aadharCard != null,
              onTap: () => _pickDocument(3),
              required: true,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Your documents are secure and will only be used for verification purposes.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
  
  Widget _buildDocumentUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool hasFile,
    required VoidCallback onTap,
    required bool required,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile 
                ? Colors.green.withOpacity(0.5) 
                : AppColors.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasFile 
                    ? Colors.green.withOpacity(0.1) 
                    : AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasFile ? Icons.check : icon,
                color: hasFile ? Colors.green : AppColors.primaryColor,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (required) ...[
                        SizedBox(width: 4),
                        Text(
                          "*",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    hasFile ? "Document uploaded" : subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
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
  
  Widget _buildBankInfoPage() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _bankFormKey,
        child: Column(
          children: [
            _buildInputField(
              controller: bankNameController,
              label: "Bank Name",
              icon: Icons.account_balance,
              validator: (value) => value!.isEmpty ? 'Bank name is required' : null,
            ),
            SizedBox(height: 16),
            _buildInputField(
              controller: accountNumberController,
              label: "Account Number",
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              validator: (value) => value!.isEmpty ? 'Account number is required' : null,
            ),
            SizedBox(height: 16),
            _buildInputField(
              controller: ifscController,
              label: "IFSC Code",
              icon: Icons.confirmation_number,
              validator: (value) => value!.isEmpty ? 'IFSC code is required' : null,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Your bank details are secure and will only be used for credit transactions.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
  
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(
            icon,
            color: AppColors.primaryColor.withOpacity(0.7),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
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
  bool shouldReclip(CustomClipper<Path> oldDelegate) => false;
}