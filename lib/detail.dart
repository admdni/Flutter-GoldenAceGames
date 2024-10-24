// lib/screens/game_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
//import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'api.dart';

class GameDetailScreen extends StatefulWidget {
  final int gameId;

  GameDetailScreen({required this.gameId});

  @override
  _GameDetailScreenState createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Future<GameDetail> gameDetail;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _loadGameDetail();

    gameDetail = _gameService.getGameDetail(widget.gameId);
  }

  Widget _buildGameImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.purple.withOpacity(0.2),
        child: Center(
          child: Icon(
            Icons.videogame_asset,
            size: 50,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.purple.withOpacity(0.2),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.purple.withOpacity(0.2),
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: Colors.white.withOpacity(0.5),
            size: 50,
          ),
        ),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch website'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching website'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A1B3D),
              Color(0xFF44318D),
            ],
          ),
        ),
        child: FutureBuilder<GameDetail>(
          future: gameDetail,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ));
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Error loading game details',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          gameDetail =
                              _gameService.getGameDetail(widget.gameId);
                        });
                      },
                      child: Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final game = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      game.name,
                      style: GoogleFonts.orbitron(
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildGameImage(game.backgroundImage),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xFF2A1B3D).withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRatingSection(game),
                        SizedBox(height: 20),
                        _buildInfoSection(game),
                        SizedBox(height: 20),
                        _buildDescription(game),
                        SizedBox(height: 20),
                        _buildPlatforms(game),
                        if (game.website.isNotEmpty) ...[
                          SizedBox(height: 20),
                          _buildWebsiteButton(game),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadGameDetail() async {
    try {
      setState(() {
        gameDetail = _gameService.getGameDetail(widget.gameId);
      });

      // Debug için API yanıtını kontrol edelim
      final response = await gameDetail;
      print('Game Detail Response: $response');
      print('Game ID: ${widget.gameId}');
    } catch (e) {
      print('Error loading game detail: $e');
    }
  }

  Widget _buildWebsiteButton(GameDetail game) {
    return ElevatedButton(
      onPressed: () => _launchURL(game.website),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.language),
          SizedBox(width: 8),
          Text('Visit Website'),
        ],
      ),
    );
  }
}

PreferredSizeWidget _buildAppBar() {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
  );
}

Widget _buildRatingSection(GameDetail game) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: Colors.purple.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 30),
            SizedBox(height: 8),
            Text(
              '${game.rating}/5',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rating',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Column(
          children: [
            Icon(Icons.timer, color: Colors.green, size: 30),
            SizedBox(height: 8),
            Text(
              '${game.playtime}h',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Playtime',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildInfoSection(GameDetail game) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Release Date',
        style: GoogleFonts.orbitron(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),
      SizedBox(height: 8),
      Text(
        game.released,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
      SizedBox(height: 16),
      Text(
        'Genres',
        style: GoogleFonts.orbitron(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),
      SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: game.genres.map((genre) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.purple.withOpacity(0.5),
              ),
            ),
            child: Text(
              genre,
              style: TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

Widget _buildDescription(GameDetail game) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'About',
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 12),
      /*HtmlWidget(
        game.description,
        customStylesBuilder: (element) {
          return {
            'color': 'white',
            'font-size': '16px',
          };
        },
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),*/
    ],
  );
}

Widget _buildPlatforms(GameDetail game) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Available Platforms',
        style: GoogleFonts.orbitron(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: game.platforms.map((platform) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              platform,
              style: TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
      ),
    ],
  );
}
