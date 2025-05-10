import 'dart:math';

import 'package:flutter/material.dart';
import 'package:craditapp/constants.dart';
import 'package:craditapp/services/shared_prefs_service.dart';
import 'package:craditapp/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _backgroundAnimationController;
  late AnimationController _contentAnimationController;
  int _currentPage = 0;
  
  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: "Welcome to CreditPump",
      subtitle: "Smart Fuel Financing",
      description: "The intelligent platform that revolutionizes how businesses and individuals access fuel credits with seamless transactions.",
      imagePath: "assets/onboarding1.jpg",
      gradientColors: [
        Color(0xFF1E3C72),
        Color(0xFF2A5298),
      ],
    ),
    OnboardingItem(
      title: "Instant Credit Access",
      subtitle: "Fuel Now, Pay Later",
      description: "Get immediate access to fuel credits with flexible repayment options tailored to your cash flow and business needs.",
      imagePath: "assets/onboarding1.jpg",
      gradientColors: [
        Color(0xFF4A00E0),
        Color(0xFF8E2DE2),
      ],
    ),
    OnboardingItem(
      title: "Secure Transactions",
      subtitle: "Bank-Grade Security",
      description: "Every transaction is protected with advanced encryption and multi-factor authentication for complete peace of mind.",
      imagePath: "assets/onboarding1.jpg",
      gradientColors: [
        Color(0xFF134E5E),
        Color(0xFF71B280),
      ],
    ),
    OnboardingItem(
      title: "Comprehensive Dashboard",
      subtitle: "Complete Financial Control",
      description: "Monitor your credit usage, track spending patterns, and manage repayments all from one intuitive dashboard.",
      imagePath: "assets/onboarding4.png",
      gradientColors: [
        Color(0xFFFF416C),
        Color(0xFFFF4B2B),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    
    _contentAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    
    _backgroundAnimationController.forward();
    _contentAnimationController.forward();
    
    _pageController.addListener(() {
      if (_pageController.page!.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
        _backgroundAnimationController.reset();
        _contentAnimationController.reset();
        _backgroundAnimationController.forward();
        _contentAnimationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
    _contentAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _items[_currentPage].gradientColors[0],
                      _items[_currentPage].gradientColors[1],
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Decorative elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          
          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                if (_currentPage < _items.length - 1)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, right: 16.0),
                      child: TextButton(
                        onPressed: () {
                          SharedPrefsService.setNotFirstTime();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) {
                      return buildOnboardingPage(_items[index]);
                    },
                  ),
                ),
                
                // Bottom navigation area
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    children: [
                      // Page indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _items.length,
                          (index) => buildPageIndicator(index),
                        ),
                      ),
                      SizedBox(height: 32),
                      
                      // Action button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _items.length - 1) {
                              // Last page, go to login
                              SharedPrefsService.setNotFirstTime();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => LoginScreen()),
                              );
                            } else {
                              // Go to next page
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _items[_currentPage].gradientColors[1],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            shadowColor: Colors.black.withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _items.length - 1 ? "Get Started" : "Next",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                _currentPage == _items.length - 1 
                                    ? Icons.login 
                                    : Icons.arrow_forward,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOnboardingPage(OnboardingItem item) {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo instead of image
              Expanded(
                flex: 5,
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _contentAnimationController,
                      curve: Interval(0.0, 0.5, curve: Curves.easeOut),
                    ),
                  ),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
                      CurvedAnimation(
                        parent: _contentAnimationController,
                        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.only(top: 40),
                      child: buildLogoForPage(_currentPage),
                    ),
                  ),
                ),
              ),
              
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // Subtitle
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _contentAnimationController,
                          curve: Interval(0.3, 0.6, curve: Curves.easeOut),
                        ),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
                          CurvedAnimation(
                            parent: _contentAnimationController,
                            curve: Interval(0.3, 0.6, curve: Curves.easeOut),
                          ),
                        ),
                        child: Text(
                          item.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    
                    // Title
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _contentAnimationController,
                          curve: Interval(0.4, 0.7, curve: Curves.easeOut),
                        ),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
                          CurvedAnimation(
                            parent: _contentAnimationController,
                            curve: Interval(0.4, 0.7, curve: Curves.easeOut),
                          ),
                        ),
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Description
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _contentAnimationController,
                          curve: Interval(0.5, 0.8, curve: Curves.easeOut),
                        ),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
                          CurvedAnimation(
                            parent: _contentAnimationController,
                            curve: Interval(0.5, 0.8, curve: Curves.easeOut),
                          ),
                        ),
                        child: Text(
                          item.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    // Additional content - Feature list
                    SizedBox(height: 14),
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _contentAnimationController,
                          curve: Interval(0.6, 0.9, curve: Curves.easeOut),
                        ),
                      ),
                      child: buildFeatureList(_currentPage),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Custom logo widget based on page index
  Widget buildLogoForPage(int pageIndex) {
    // Different logo styles for each page
    IconData iconData;
    List<Color> iconGradient;
    
    switch(pageIndex) {
      case 0:
        iconData = Icons.account_balance_wallet;
        iconGradient = [Colors.white, Colors.white70];
        break;
      case 1:
        iconData = Icons.credit_card;
        iconGradient = [Colors.white, Colors.white70];
        break;
      case 2:
        iconData = Icons.security;
        iconGradient = [Colors.white, Colors.white70];
        break;
      case 3:
        iconData = Icons.dashboard;
        iconGradient = [Colors.white, Colors.white70];
        break;
      default:
        iconData = Icons.account_balance_wallet;
        iconGradient = [Colors.white, Colors.white70];
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated logo container
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _items[pageIndex].gradientColors[0].withOpacity(0.8),
                _items[pageIndex].gradientColors[1].withOpacity(0.4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _items[pageIndex].gradientColors[0].withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  colors: iconGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds);
              },
              child: Icon(
                iconData,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ),
        
        SizedBox(height: 20),
        
        // CreditPump text logo
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Credit",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: "Pump",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Feature list based on page index
  Widget buildFeatureList(int pageIndex) {
    List<String> features = [];
    
    switch(pageIndex) {
      case 0:
        features = [
          "Quick application process",
          "No paperwork hassle",
          "Transparent terms & conditions"
        ];
        break;
      case 1:
        features = [
          "Flexible repayment options",
          "Competitive interest rates",
          "No hidden charges"
        ];
        break;
      case 2:
        features = [
          "End-to-end encryption",
          "Biometric authentication",
          "Fraud detection systems"
        ];
        break;
      case 3:
        features = [
          "Real-time transaction tracking",
          "Expense categorization",
          "Payment reminders"
        ];
        break;
      default:
        features = [];
    }
    
    return Container(
      constraints: BoxConstraints(maxHeight: 100), // Limit maximum height
      child: SingleChildScrollView( // Make it scrollable if needed
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take minimum space needed
          children: features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 6.0), // Reduced padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multi-line text
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16, // Smaller icon
                ),
                SizedBox(width: 6), // Reduced spacing
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13, // Smaller font size
                    ),
                    maxLines: 2, // Limit to 2 lines
                    overflow: TextOverflow.ellipsis, // Show ellipsis if text overflows
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
  Widget buildPageIndicator(int index) {
    bool isCurrentPage = index == _currentPage;
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isCurrentPage ? 24 : 8,
      decoration: BoxDecoration(
        color: isCurrentPage ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final String imagePath;
  final List<Color> gradientColors;

  OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imagePath,
    required this.gradientColors,
  });
}