import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class PrivacyPolicyScreen extends StatefulWidget {
  @override
  _PrivacyPolicyScreenState createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  Future<String>? _loadPrivacyPolicy;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy = _loadPrivacyPolicyFromAssets();
  }

  Future<String> _loadPrivacyPolicyFromAssets() async {
    return await rootBundle.loadString('assets/privacypolicy.txt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy'),
        backgroundColor: Colors.blueAccent, // AppBar arka plan rengi
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<String>(
          future: _loadPrivacyPolicy,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error loading privacy policy'));
            } else {
              return SingleChildScrollView(
                child: Text(
                  snapshot.data ?? '',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
