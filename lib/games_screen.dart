import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:golden_ace_games/blackjack.dart';
import 'package:golden_ace_games/cosmic_slot.dart';
import 'package:golden_ace_games/homePage.dart';
import 'package:golden_ace_games/poker_game.dart';
import 'package:golden_ace_games/trivia_games.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class GamesScreen extends StatefulWidget {
  @override
  _GamesScreenState createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _cardAnimations;
  bool isSlotGameVisible = false;
  Timer? _apiCheckTimer;

  // Ana oyun listesi
  final List<Map<String, dynamic>> baseGames = [
    {
      'name': ' Trivia',
      'description': 'Test your quiz skill',
      'icon': Icons.question_answer,
      'color': Colors.purpleAccent,
      'onTap': TriviaApp(),
    },
    {
      'name': ' Matching',
      'description': 'Level based matching game.',
      'icon': Icons.games_rounded,
      'color': const Color.fromARGB(255, 70, 110, 243),
      'onTap': GalacticMatch(),
    },
    {
      'name': ' Shooter ',
      'description': 'a war against asteroids!',
      'icon': Icons.color_lens,
      'color': Colors.pinkAccent,
      'onTap': CosmicShooter(),
    },
  ];

  // Slot oyunu
  final Map<String, dynamic> slotGame = {
    'name': 'Cosmic Slot Machine',
    'description': 'Test your luck in the cosmic casino!',
    'icon': Icons.casino,
    'color': Colors.purpleAccent,
    'onTap': CosmicSlotGame(),
  };

  List<Map<String, dynamic>> games = [];

  @override
  void initState() {
    super.initState();
    games = List.from(baseGames);

    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _initializeAnimations();
    _checkSlotGameVisibility();

    // Her 5 dakikada bir API kontrolü
    _apiCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _checkSlotGameVisibility();
    });
  }

  Future<void> _checkSlotGameVisibility() async {
    try {
      final response = await http.get(
        Uri.parse('https://appledeveloper.com.tr/screen/screen.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['screen'] == 1) {
            if (!games.any((game) => game['name'] == slotGame['name'])) {
              games.add(slotGame);
            }
            isSlotGameVisible = true;
          } else {
            games.removeWhere((game) => game['name'] == slotGame['name']);
            isSlotGameVisible = false;
          }
          _initializeAnimations();
        });
      }
    } catch (e) {
      print('Error fetching screen status: $e');
    }
  }

  void _initializeAnimations() {
    _cardAnimations = List.generate(
      games.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.15,
            0.5 + index * 0.15,
            curve: Curves.easeOut,
          ),
        ),
      ),
    );

    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _apiCheckTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => GoldenAceHome()),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/black_jack.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: CustomScrollView(
              physics: BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Choose Your Game',
                      style: GoogleFonts.cinzelDecorative(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.purpleAccent,
                            blurRadius: 12,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => AnimatedBuilder(
                        animation: _cardAnimations[index],
                        builder: (context, child) {
                          double opacity =
                              _cardAnimations[index].value.clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(
                                0, 50 * (1 - _cardAnimations[index].value)),
                            child: Opacity(
                              opacity: opacity,
                              child:
                                  _buildGameCard(context, games[index], index),
                            ),
                          );
                        },
                      ),
                      childCount: games.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(
      BuildContext context, Map<String, dynamic> game, int index) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToGame(context, game),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  game['color'].withOpacity(0.9),
                  game['color'].withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: game['color'].withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -40,
                  child: Icon(
                    game['icon'] as IconData,
                    size: 200,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  game['icon'] as IconData,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  game['name'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            game['description'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _navigateToGame(context, game),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: game['color'],
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            textStyle: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('PLAY NOW'),
                              SizedBox(width: 8),
                              Icon(Icons.play_arrow),
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
        ),
      ),
    );
  }

  void _navigateToGame(BuildContext context, Map<String, dynamic> game) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => game['onTap'],
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }
}
