import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;

  HomeScreen({this.userData});

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return Scaffold(
        body: Center(child: Text("No user data available")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Home")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome, ${userData?['name'] ?? 'User'}",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text("Phone Number: ${userData?['phoneNo'] ?? 'Not Available'}"),
            SizedBox(height: 10),
            Text("Category: ${userData?['merchantInfo']['category'] ?? 'Not Available'}"),
            SizedBox(height: 10),
            Text("Address: ${userData?['merchantInfo']['address'] ?? 'Not Available'}"),
            SizedBox(height: 10),
            Text("GST Number: ${userData?['merchantInfo']['gstNumber'] ?? 'Not Available'}"),
          ],
        ),
      ),
    );
  }
}
