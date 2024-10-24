// lib/screens/galactic_games_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:golden_ace_games/api.dart';
import 'package:golden_ace_games/detail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'homePage.dart';

class GalacticGamesScreen extends StatefulWidget {
  @override
  _GalacticGamesScreenState createState() => _GalacticGamesScreenState();
}

class _GalacticGamesScreenState extends State<GalacticGamesScreen> {
  final GameService _gameService = GameService();
  late Future<List<Game>> featuredGames;
  late Future<List<Game>> allGames;
  late Future<List<Genre>> genres;
  String? selectedGenre;
  String selectedCategory = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;

  final List<String> categories = [
    'All',
    'Action',
    'RPG',
    'Strategy',
    'Adventure',
    'Simulation',
    'Sports',
    'Racing',
    'Shooter'
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    featuredGames = _gameService.getFeaturedGames();
    genres = _gameService.getGenres();
    allGames = _gameService.getGames();
  }

  Future<void> _refreshGames() async {
    setState(() {
      _initializeData();
    });
  }

  Future<void> _searchGames(String query) async {
    setState(() {
      isLoading = true;
    });

    try {
      final games = await _gameService.getGames(search: query);
      setState(() {
        allGames = Future.value(games);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching games')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Şeffaf renk.
        elevation: 0, // Gölgeyi kaldırır.
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Colors.white), // Geri dönme ikonu.
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      GoldenAceHome()), // GoldenAceHome sayfasına git
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2A1B3D), // Koyu mor
              Color(0xFF44318D), // Orta mor
              Color(0xFF3B2667), // Açık mor
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshGames,
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildFeaturedGamesSection(),
                        _buildCategories(),
                        _buildAllGamesSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search Galactic Games...',
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.purple.shade200),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: isLoading
              ? Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.purple.shade200,
                  ),
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
          if (value.length >= 3) {
            _searchGames(value);
          } else if (value.isEmpty) {
            _refreshGames();
          }
        },
      ),
    );
  }

  Widget _buildFeaturedGamesSection() {
    return FutureBuilder<List<Game>>(
      future: featuredGames,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading featured games'));
        }
        final games = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Featured Games',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            CarouselSlider.builder(
              itemCount: games.length,
              options: CarouselOptions(
                height: 200,
                viewportFraction: 0.8,
                enlargeCenterPage: true,
                autoPlay: true,
                autoPlayInterval: Duration(seconds: 3),
              ),
              itemBuilder: (context, index, realIndex) {
                final game = games[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GameDetailScreen(gameId: game.id),
                    ),
                  ),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: game.backgroundImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) =>
                                Icon(Icons.error),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  game.name,
                                  style: GoogleFonts.orbitron(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.star,
                                        color: Colors.amber, size: 20),
                                    SizedBox(width: 4),
                                    Text(
                                      game.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadGamesByGenre(String genreSlug) async {
    setState(() {
      isLoading = true;
    });

    try {
      final games = await _gameService.getGames(category: genreSlug);
      setState(() {
        allGames = Future.value(games);
        selectedGenre = genreSlug;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading games')),
        );
      }
    }
  }

  Widget _buildCategories() {
    return Container(
      height: 60,
      margin: EdgeInsets.symmetric(vertical: 16),
      child: FutureBuilder<List<Genre>>(
        future: genres,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading categories'));
          }

          final genreList = snapshot.data ?? [];

          // All kategorisini en başa ekleyelim
          final allCategories = [
            Genre(
              id: -1,
              name: 'All',
              slug: 'all',
              gamesCount: 0,
            ),
            ...genreList,
          ];

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final genre = allCategories[index];
              final isSelected = genre.slug == selectedGenre;

              return GestureDetector(
                onTap: () {
                  if (genre.slug == 'all') {
                    _initializeData();
                  } else {
                    _loadGamesByGenre(genre.slug);
                  }
                },
                child: Container(
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.purple.shade700
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? Colors.purple
                          : Colors.purple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      genre.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAllGamesSection() {
    return FutureBuilder<List<Game>>(
      future: allGames,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading games'));
        }
        final games = snapshot.data ?? [];

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: MasonryGridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameDetailScreen(gameId: game.id),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.purple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: game.backgroundImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              color: Colors.purple.withOpacity(0.2),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              Icon(Icons.error),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    game.genres.isNotEmpty
                                        ? game.genres[0]
                                        : 'Unknown',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  game.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
