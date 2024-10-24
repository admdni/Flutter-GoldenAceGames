// lib/services/game_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class GameService {
  static const String baseUrl = 'https://api.rawg.io/api';
  static const String apiKey =
      '29baf58b6b9d4b7fb3a23ecb55dbc0bb'; // RAWG API key'inizi buraya ekleyin

  static const Map<String, String> _categoryMapping = {
    'Action': 'action',
    'RPG': 'role-playing-games-rpg',
    'Strategy': 'strategy',
    'Adventure': 'adventure',
    'Simulation': 'simulation',
    'Sports': 'sports',
    'Racing': 'racing',
    'Shooter': 'shooter'
  };

  Future<List<Game>> getFeaturedGames() async {
    final response = await http.get(
      Uri.parse('$baseUrl/games?key=$apiKey&ordering=-rating&page_size=5'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List)
          .map((game) => Game.fromJson(game))
          .toList();
    }
    throw Exception('Failed to load featured games');
  }

  Future<List<Game>> getGames({String? category, String? search}) async {
    String url = '$baseUrl/games?key=$apiKey';
    if (category != null && category != 'all') {
      url += '&genres=$category';
    }
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }

    final response = await http.get(Uri.parse(url));

    if (category != null && category != 'All') {
      final genreSlug = _categoryMapping[category];
      if (genreSlug != null) {
        url += '&genres=$genreSlug';
        print('Loading games for category: $category (slug: $genreSlug)');
      }
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List)
          .map((game) => Game.fromJson(game))
          .toList();
    }
    throw Exception('Failed to load games');
  }

  Future<GameDetail> getGameDetail(int id) async {
    try {
      final url = '$baseUrl/games/$id?key=$apiKey';
      print('Requesting URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // API yanıtının bir Map olduğundan emin olalım
        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid API response format');
        }

        // API yanıtını kontrol edelim
        print('API Response: $data');

        return GameDetail.fromJson(data);
      } else {
        throw Exception(
            'Failed to load game details. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getGameDetail: $e');
      throw Exception('Failed to load game details: $e');
    }
  }

  Future<List<Genre>> getGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/genres?key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['results'] as List)
            .map((genre) => Genre.fromJson(genre))
            .toList();
      } else {
        throw Exception('Failed to load genres');
      }
    } catch (e) {
      print('Error fetching genres: $e');
      throw Exception('Failed to load genres');
    }
  }
}

// lib/models/game.dart
class Game {
  final int id;
  final String name;
  final String backgroundImage; // nullable olarak işaretlendi
  final double rating;
  final List<String> genres;
  final String released;

  Game({
    required this.id,
    required this.name,
    required this.backgroundImage,
    required this.rating,
    required this.genres,
    required this.released,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      name: json['name'],
      backgroundImage: json['background_image'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      genres: (json['genres'] as List?)
              ?.map((genre) => genre['name'] as String)
              .toList() ??
          [],
      released: json['released'] ?? '',
    );
  }
}

// lib/models/game_detail.dart
class GameDetail {
  final int id;
  final String name;
  final String? backgroundImage;
  final String description;
  final double rating;
  final int playtime;
  final String released;
  final List<String> genres;
  final List<String> platforms;
  final String website;
  final List<Rating> ratings; // Yeni eklenen alan

  GameDetail({
    required this.id,
    required this.name,
    this.backgroundImage,
    required this.description,
    required this.rating,
    required this.playtime,
    required this.released,
    required this.genres,
    required this.platforms,
    required this.website,
    required this.ratings,
  });

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    try {
      return GameDetail(
        id: json['id'] ?? 0,
        name: json['name'] ?? 'Unknown',
        backgroundImage: json['background_image'],
        description: json['description'] ?? '',
        rating: (json['rating'] ?? 0.0).toDouble(),
        playtime: json['playtime'] ?? 0,
        released: json['released'] ?? 'TBA',
        genres: (json['genres'] as List?)
                ?.map((genre) => genre['name'].toString())
                .toList() ??
            [],
        platforms: (json['parent_platforms'] as List?)
                ?.map((platform) => platform['platform']['name'].toString())
                .toList() ??
            [],
        website: json['website'] ?? '',
        ratings: (json['ratings'] as List?)
                ?.map((rating) => Rating.fromJson(rating))
                .toList() ??
            [],
      );
    } catch (e) {
      print('Error parsing GameDetail JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class Rating {
  final int id;
  final String title;
  final int count;
  final double percent;

  Rating({
    required this.id,
    required this.title,
    required this.count,
    required this.percent,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      count: json['count'] ?? 0,
      percent: (json['percent'] ?? 0.0).toDouble(),
    );
  }
}

class Genre {
  final int id;
  final String name;
  final String slug;
  final String? imageBackground;
  final int gamesCount;

  Genre({
    required this.id,
    required this.name,
    required this.slug,
    this.imageBackground,
    required this.gamesCount,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      imageBackground: json['image_background'],
      gamesCount: json['games_count'],
    );
  }
}
