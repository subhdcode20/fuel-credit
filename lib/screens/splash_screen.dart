import 'dart:math';

import 'package:flutter/material.dart';
import 'package:craditapp/constants.dart';
import 'package:craditapp/services/shared_prefs_service.dart';
import 'package:craditapp/screens/onboarding_screen.dart';
import 'package:craditapp/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craditapp/MerchantHomeScreen.dart';
import 'package:craditapp/DriverHomeScreen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    
    _controller.forward();
    
    // Auto-navigate after 3 seconds
    Timer(Duration(seconds: 3), () {
      _navigateToNextScreen();
    });
  }
  
  void _navigateToNextScreen() async {
    // Check if user is already logged in with Firebase
    User? currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // User is logged in, check user type in Firestore
      try {
        final String? phoneNumber = currentUser.phoneNumber;
        
        if (phoneNumber != null) {
          // Fetch user data from Firestore
          final docSnapshot = await FirebaseFirestore.instance
              .collection('userDetails')
              .doc(phoneNumber)
              .get();
          
          if (docSnapshot.exists) {
            final userData = docSnapshot.data();
            final userType = userData?['userType'];
            
            if (mounted) {
              if (userType == 'merchant') {
                // Navigate to Merchant Home Screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MerchantHomeScreen(userData: userData!)),
                );
                return;
              } else if (userType == 'client') {
                // Navigate to Driver Home Screen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => DriverHomeScreen(userData: userData!)),
                );
                return;
              }
            }
          }
        }
      } catch (e) {
        print('Error checking user data: $e');
      }
    }
    
    // If we reach here, either user is not logged in or there was an error
    // Fall back to the original navigation logic
    bool isFirstTime = await SharedPrefsService.isFirstTime();
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => isFirstTime ? OnboardingScreen() : LoginScreen(),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: SplashWavePainter(
                  animation: _controller.value,
                ),
                child: Container(),
              );
            },
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primaryColor.withOpacity(0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // Main circle
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primaryColor,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryColor.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),
                          // Logo elements
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 50,
                              ),
                              SizedBox(height: 5),
                              Container(
                                width: 60,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                SizedBox(height: 40),
                
                // Text animation
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Column(
                        children: [
                          Text(
                            "finWallet",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Welcome to CreditPump",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Sign to access your account below.",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Animated loading indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Text("1.0 V", style: TextStyle(color: Colors.white)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashWavePainter extends CustomPainter {
  final double animation;
  
  SplashWavePainter({required this.animation});
  
  @override
  void paint(Canvas canvas, Size size) {
    // Create multiple animated wave layers
    _drawWave(canvas, size, 0.15, animation, 0.8);
    _drawWave(canvas, size, 0.25, animation * 1.2, 0.6);
    _drawWave(canvas, size, 0.35, animation * 0.8, 0.4);
  }
  
  void _drawWave(Canvas canvas, Size size, double opacity, double animValue, double heightFactor) {
    var paint = Paint()
      ..color = AppColors.primaryColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;
      
    var path = Path();
    
    double waveHeight = size.height * heightFactor;
    
    path.moveTo(0, waveHeight);
    
    for (int i = 0; i < size.width.toInt(); i++) {
      double x = i.toDouble();
      double sinValue = sin((x / size.width * 4 * pi) + (animValue * pi * 2));
      double y = waveHeight + sinValue * 20 * animValue;
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant SplashWavePainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}