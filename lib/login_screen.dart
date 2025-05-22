import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:craditapp/constants.dart';
import 'package:craditapp/otp_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final phoneController = TextEditingController();
  bool isLoading = false;
  
  // Animation controllers
  late AnimationController _backgroundAnimController;
  late AnimationController _cardAnimController;
  late AnimationController _logoAnimController;
  late AnimationController _loadingAnimController;
  
  // Animations
  late Animation<double> _backgroundAnim;
  late Animation<double> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;
  late Animation<double> _logoScaleAnim;
  
  // Particles for background effect
  final List<Particle> _particles = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize background animation controller
    _backgroundAnimController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    )..repeat();
    
    _backgroundAnim = Tween<double>(begin: 0, end: 1).animate(_backgroundAnimController);
    
    // Initialize card animation controller
    _cardAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _cardSlideAnim = Tween<double>(begin: 100, end: 0).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutQuint),
    );
    
    _cardFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOut),
    );
    
    // Initialize logo animation controller
    _logoAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    
    _logoScaleAnim = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _logoAnimController, curve: Curves.elasticOut),
    );
    
    // Initialize loading animation controller
    _loadingAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    // Generate particles for background
    _generateParticles();
    
    // Start animations with slight delays for better effect
    Future.delayed(Duration(milliseconds: 100), () {
      _logoAnimController.forward();
    });
    
    Future.delayed(Duration(milliseconds: 300), () {
      _cardAnimController.forward();
    });
  }
  
  void _generateParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(Particle(
        position: Offset(
          _random.nextDouble() * 400,
          _random.nextDouble() * 800,
        ),
        size: _random.nextDouble() * 15 + 5,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        speed: _random.nextDouble() * 1.5 + 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _backgroundAnimController.dispose();
    _cardAnimController.dispose();
    _logoAnimController.dispose();
    _loadingAnimController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void sendOTP() async {
    if (phoneController.text.trim().isEmpty) {
      _showErrorSnackbar('Please enter your phone number');
      return;
    }
    
    if (phoneController.text.trim().length != 10) {
      _showErrorSnackbar('Please enter a valid 10-digit phone number');
      return;
    }

    setState(() {
      isLoading = true;
    });
    
    // Start loading animation
    _loadingAnimController.repeat();

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            isLoading = false;
          });
          _loadingAnimController.stop();
          _showErrorSnackbar('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            isLoading = false;
          });
          _loadingAnimController.stop();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                OTPScreen(verificationId: verificationId),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                var begin = Offset(1.0, 0.0);
                var end = Offset.zero;
                var curve = Curves.easeInOutQuart;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _loadingAnimController.stop();
      _showErrorSnackbar('Error: ${e.toString()}');
    }
  }
  
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
        elevation: 8,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundAnim,
            builder: (context, child) {
              return CustomPaint(
                painter: BackgroundPainter(
                  animation: _backgroundAnim.value,
                  particles: _particles,
                ),
                size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              );
            },
          ),
          
          // Blurred overlay for depth
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.backgroundDark.withOpacity(0.8),
                    AppColors.backgroundDark.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 60),
                    
                    // Animated logo
                    AnimatedBuilder(
                      animation: _logoScaleAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _logoScaleAnim.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.primaryColor,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // App name with shimmer effect
                    ShimmerText(
                      text: "CreditPump",
                      baseColor: Colors.white,
                      highlightColor: AppColors.primaryLight,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Text(
                      "Your Financial Freedom Partner",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: 60),
                    
                    // Login card with animation
                    AnimatedBuilder(
                      animation: _cardAnimController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _cardSlideAnim.value),
                          child: Opacity(
                            opacity: _cardFadeAnim.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Sign in with your phone number",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 32),
                            
                            // Phone input field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Phone Number",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isLoading 
                                          ? AppColors.primaryColor 
                                          : Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Country code
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              "+91",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.white54,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Phone input
                                      Expanded(
                                        child: TextField(
                                          controller: phoneController,
                                          style: TextStyle(color: Colors.white),
                                          keyboardType: TextInputType.phone,
                                          enabled: !isLoading,
                                          decoration: InputDecoration(
                                            hintText: "10-digit mobile number",
                                            hintStyle: TextStyle(color: Colors.white38),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 32),
                            
                            // Login button with loading animation
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : sendOTP,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? LoadingIndicator()
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Continue",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Terms and conditions
                            Center(
                              child: Text(
                                "By continuing, you agree to our Terms of Service\nand Privacy Policy",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom loading indicator with animated dots
class LoadingIndicator extends StatefulWidget {
  @override
  _LoadingIndicatorState createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator> with TickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Verifying",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              children: [
                _buildDot(0),
                _buildDot(1),
                _buildDot(2),
              ],
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildDot(int index) {
    double delay = index * 0.2;
    final Animation<double> animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          delay,
          delay + 0.5,
          curve: Curves.easeInOut,
        ),
      ),
    );
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          width: 4 + (animation.value * 4),
          height: 4 + (animation.value * 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6 + (animation.value * 0.4)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

// Shimmer text effect for app name
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color baseColor;
  final Color highlightColor;
  
  const ShimmerText({
    required this.text,
    required this.style,
    required this.baseColor,
    required this.highlightColor,
  });
  
  @override
  _ShimmerTextState createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2500),
    )..repeat();
  }
  
  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                0.0,
                _shimmerController.value,
                1.0,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.style,
          ),
        );
      },
    );
  }
}

// Particle class for background effect
class Particle {
  Offset position;
  double size;
  double opacity;
  double speed;
  
  Particle({
    required this.position,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

// Background painter with animated particles
class BackgroundPainter extends CustomPainter {
  final double animation;
  final List<Particle> particles;
  
  BackgroundPainter({
    required this.animation,
    required this.particles,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw gradient background
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Gradient gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A1A2E),
        Color(0xFF16213E),
      ],
      stops: [0.0, 1.0],
    );
    
    final Paint backgroundPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, backgroundPaint);
    
    // Draw animated particles
    for (var particle in particles) {
      final y = (particle.position.dy + (animation * particle.speed * 100)) % size.height;
      
      final Paint particlePaint = Paint()
        ..color = AppColors.primaryColor.withOpacity(particle.opacity * (0.5 + (sin(animation * 2 * pi) + 1) / 4))
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle.position.dx, y),
        particle.size * (0.8 + (sin(animation * 2 * pi + particle.position.dx) + 1) / 5),
        particlePaint,
      );
    }
    
    // Draw subtle glow effects
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryColor.withOpacity(0.2),
          AppColors.primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.8, size.height * 0.2),
        radius: size.width * 0.5,
      ));
    
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      size.width * 0.5,
      glowPaint,
    );
    
    final Paint glowPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primaryDark.withOpacity(0.15),
          AppColors.primaryDark.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.8),
        radius: size.width * 0.4,
      ));
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      size.width * 0.4,
      glowPaint2,
    );
  }
  
  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}