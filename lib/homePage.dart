// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_ace_games/galactic_games.dart';
import 'package:golden_ace_games/games_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import 'blackjack.dart';
import 'cosmic_slot.dart';
import 'poker_game.dart';
import 'privacy_policy.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galactic  Game ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: GoldenAceHome(),
    );
  }
}

// Home Screen
class GoldenAceHome extends StatefulWidget {
  @override
  _GoldenAceHomeState createState() => _GoldenAceHomeState();
}

class _GoldenAceHomeState extends State<GoldenAceHome>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _buttonAnimations;

  final List<Map<String, dynamic>> mainButtons = [
    {
      'name': 'Games Hub',
      'icon': Icons.games,
      'color': Colors.blue.shade400,
      'onTap': (BuildContext context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GalacticGamesScreen()),
          ),
    },
    {
      'name': 'Play Games',
      'icon': Icons.gamepad_sharp,
      'color': Colors.green.shade400,
      'onTap': (BuildContext context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GamesScreen()),
          ),
    },
    {
      'name': 'Rate Us',
      'icon': Icons.star,
      'color': Colors.amber.shade400,
      'action': 'rate'
    },
    {
      'name': 'Share',
      'icon': Icons.share,
      'color': Colors.purple.shade400,
      'action': 'share'
    },
    {
      'name': 'Exit',
      'icon': Icons.outdoor_grill,
      'color': const Color.fromARGB(255, 154, 200, 27),
      'onTap': (BuildContext context) => _showExitDialog(context)
    },
    {
      'name': 'Privacy Policy',
      'icon': Icons.outdoor_grill,
      'color': const Color.fromARGB(255, 242, 99, 10),
      'onTap': (BuildContext context) => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PrivacyPolicyScreen()),
          ),
    },
  ];

  final List<Map<String, dynamic>> games = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _buttonAnimations = List.generate(
      mainButtons.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            0.5 + index * 0.1,
            curve: Curves.elasticOut,
          ),
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.withOpacity(0.8),
                      Colors.blue.withOpacity(0.5),
                      Colors.black,
                    ],
                    stops: [0.0, 0.5, 1.0],
                    transform:
                        GradientRotation(_controller.value * 2 * 3.14159),
                  ),
                ),
              );
            },
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 30),
                    _buildAnimatedHeader(),
                    SizedBox(height: 40),
                    _buildMainButtonsGrid(),
                    SizedBox(height: 30),
                    _buildGamesSection(),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 1200),
      tween: Tween(begin: -100.0, end: 0.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(value, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.purple, Colors.blue, Colors.amber],
                  stops: [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  'Galactic',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                ' Game',
                style: GoogleFonts.cinzelDecorative(
                  fontSize: 24,
                  color: Colors.amberAccent,
                  shadows: [
                    Shadow(color: Colors.purple, blurRadius: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainButtonsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
      ),
      itemCount: mainButtons.length,
      itemBuilder: (context, index) {
        return ScaleTransition(
          scale: _buttonAnimations[index],
          child: _buildAnimatedButton(mainButtons[index]),
        );
      },
    );
  }

  Widget _buildAnimatedButton(Map<String, dynamic> button) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: button['color'].withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleButtonTap(button),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  button['color'].withOpacity(0.8),
                  button['color'].withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    button['icon'],
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  button['name'],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            '',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 800),
              tween: Tween(begin: 1.5, end: 0.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value * 50),
                  child: Opacity(
                    opacity: 1 - (value / 1.5).clamp(0.0, 1.0),
                    child: _buildGameCard(game),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: game['color'].withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleGameTap(game),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!.withOpacity(0.9),
                  Colors.grey[800]!.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: game['color'].withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    game['icon'],
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    game['name'],
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleButtonTap(Map<String, dynamic> button) {
    if (button['action'] == 'share') {
      shareApp(context);
    } else if (button['action'] == 'rate') {
      rateApp(context);
    } else if (button['onTap'] != null) {
      button['onTap'](context);
    }
  }

  void _handleGameTap(Map<String, dynamic> game) {
    if (game['onTap'] != null) {
      game['onTap'](context);
    }
  }
}

Future<void> rateApp(BuildContext context) async {
  try {
    final InAppReview inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    } else {
      showSnackBar(context, "Rating is not available at the moment.");
    }
  } catch (e) {
    showSnackBar(context, "Unable to open rating. Please try again later.");
  }
}

void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(12),
    ),
  );
}

Future<void> shareApp(BuildContext context) async {
  try {
    await Share.share('Check out Golden Ace Mini Games!');
  } catch (e) {
    showSnackBar(context, "Unable to share. Please try again later.");
  }
}

Future<void> _showExitDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Exit Game',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to exit?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => exit(0),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Exit'),
          ),
        ],
      );
    },
  );
}
