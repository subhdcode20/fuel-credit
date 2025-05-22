import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

/// Privacy policy screen with a professional, comprehensive layout.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

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
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Privacy Policy',
                    style: AppTextStyles.heading1.copyWith(
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Introduction
                  _buildSectionCard(
                    title: 'Introduction',
                    content: 'Welcome to Cradit App. We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, store, and protect your data when you use our application.',
                    icon: Icons.info_outline,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Information We Collect
                  _buildExpandableSection(
                    title: 'Information We Collect',
                    icon: Icons.folder_open,
                    children: [
                      _buildSubsection(
                        title: 'Personal Information',
                        content: '• Account Information: Name, phone number, email address, and profile pictures\n'
                            '• Identity Documents: Driver\'s license, Aadhaar card, PAN card, and other KYC documents\n'
                            '• Financial Information: Bank account details, credit information, and transaction history\n'
                            '• Business Information: For merchants, we collect business registration details, GST information, company PAN, and store information',
                      ),
                      _buildSubsection(
                        title: 'Automatically Collected Information',
                        content: '• Device Information: Device type, operating system, unique device identifiers\n'
                            '• Usage Data: How you interact with our app, features used, and time spent\n'
                            '• Location Data: With your permission, we collect location data to provide location-based services',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // How We Use Your Information
                  _buildExpandableSection(
                    title: 'How We Use Your Information',
                    icon: Icons.security,
                    children: [
                      _buildSubsection(
                        title: '',
                        content: 'We use your information to:\n'
                            '• Create and manage your account\n'
                            '• Process transactions and payments\n'
                            '• Verify your identity through KYC procedures\n'
                            '• Provide customer support\n'
                            '• Improve our services and develop new features\n'
                            '• Comply with legal obligations\n'
                            '• Detect and prevent fraudulent activities',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Data Storage and Security
                  _buildSectionCard(
                    title: 'Data Storage and Security',
                    content: 'We implement industry-standard encryption and security measures to protect your data. Access to your personal information is restricted to authorized personnel only. Your data is stored on secure servers with regular backups to prevent data loss.',
                    icon: Icons.shield,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Data Sharing
                  _buildExpandableSection(
                    title: 'Data Sharing',
                    icon: Icons.share,
                    children: [
                      _buildSubsection(
                        title: '',
                        content: 'We may share your information with:\n'
                            '• Service Providers: Third-party vendors who help us operate our business\n'
                            '• Financial Institutions: Banks and payment processors to complete transactions\n'
                            '• Regulatory Authorities: When required by law or to comply with legal processes\n'
                            '• Business Partners: With your consent, we may share data with our business partners\n\n'
                            'We do not sell your personal information to third parties.',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Your Rights
                  _buildExpandableSection(
                    title: 'Your Rights',
                    icon: Icons.gavel,
                    children: [
                      _buildSubsection(
                        title: '',
                        content: 'You have the right to:\n'
                            '• Access the personal information we hold about you\n'
                            '• Request correction of inaccurate information\n'
                            '• Request deletion of your data (subject to legal requirements)\n'
                            '• Opt-out of certain data collection and processing activities\n'
                            '• Withdraw consent where processing is based on consent',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Cookies and Similar Technologies
                  _buildSectionCard(
                    title: 'Cookies and Technologies',
                    content: 'Our app may use cookies and similar technologies to enhance your experience and collect information about how you use our application.',
                    icon: Icons.cookie,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Changes to This Policy
                  _buildSectionCard(
                    title: 'Changes to This Policy',
                    content: 'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.',
                    icon: Icons.update,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Contact Us
                  _buildSectionCard(
                    title: 'Contact Us',
                    content: 'If you have any questions about this Privacy Policy or our data practices, please contact us at:\n'
                        '• Email: ranpariyatirth5@gmail.com\n'
                        '• Phone: +91 9510221179',
                    icon: Icons.contact_mail,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Compliance
                  _buildSectionCard(
                    title: 'Compliance',
                    content: 'This Privacy Policy complies with applicable data protection laws and regulations.',
                    icon: Icons.verified,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Accept button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds a card for a policy section.
  Widget _buildSectionCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.2),
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
                color: AppColors.accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Builds an expandable section with multiple subsections.
  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Theme(
      data: ThemeData(
        dividerColor: Colors.transparent,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryColor,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ExpansionTile(
          leading: Icon(
            icon,
            color: AppColors.accentColor,
          ),
          title: Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: AppColors.accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          iconColor: AppColors.accentColor,
          collapsedIconColor: AppColors.accentColor,
          childrenPadding: const EdgeInsets.all(20),
          children: children,
        ),
      ),
    );
  }
  
  /// Builds a subsection within an expandable section.
  Widget _buildSubsection({
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          content,
          style: AppTextStyles.body.copyWith(
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}