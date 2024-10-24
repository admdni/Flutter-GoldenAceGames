import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_ace_games/homePage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Game object types
enum GameObjectType { player, enemy, meteor, laser, powerUp, explosion }

// Power-up types
enum PowerUpType { shield, doubleLaser, speedBoost }

// Base game object class with improved properties
class GameObject {
  GameObjectType type;
  Offset position;
  Size size;
  bool isActive;
  double speed;
  Color color;
  PowerUpType? powerUpType;
  double rotation; // Added rotation property
  double health; // Added health property

  GameObject({
    required this.type,
    required this.position,
    required this.size,
    this.isActive = true,
    required this.speed,
    required this.color,
    this.powerUpType,
    this.rotation = 0.0,
    this.health = 100.0,
  });

  // Collision detection helper method
  bool collidesWith(GameObject other) {
    return position.dx < other.position.dx + other.size.width &&
        position.dx + size.width > other.position.dx &&
        position.dy < other.position.dy + other.size.height &&
        position.dy + size.height > other.position.dy;
  }

  // Update position based on velocity and delta time
  void update(double dt) {
    // Lazerler için özel hareket
    if (type == GameObjectType.laser) {
      position = Offset(
        position.dx,
        position.dy - speed, // Yukarı doğru düz hareket
      );
      return;
    }

    // Diğer nesneler için normal hareket
    position = Offset(
      position.dx + speed * cos(rotation) * dt,
      position.dy + speed * sin(rotation) * dt,
    );
  }
}

class CosmicShooter extends StatefulWidget {
  const CosmicShooter({Key? key}) : super(key: key);

  @override
  _CosmicShooterState createState() => _CosmicShooterState();
}

class GameState {
  bool isPlaying = false;
  bool isPaused = false;
  int score = 0;
  int highScore = 0;
  int level = 1;
  double playerHealth = 100;
  bool hasShield = false;
  bool hasDoubleLaser = false;
  bool hasSpeedBoost = false;
  DateTime lastUpdateTime = DateTime.now();

  void reset() {
    isPlaying = false;
    isPaused = false;
    score = 0;
    level = 1;
    playerHealth = 100;
    hasShield = false;
    hasDoubleLaser = false;
    hasSpeedBoost = false;
    lastUpdateTime = DateTime.now();
  }
}

class GameConfig {
  static const double baseEnemySpeed = 3.0; // Düşman hızı arttırıldı
  static const double baseMeteorSpeed = 4.0; // Meteor hızı arttırıldı
  static const double baseLaserSpeed =
      20.0; // Mermi hızı önemli ölçüde arttırıldı
  static const double playerBaseSpeed = 8.0; // Oyuncu hızı arttırıldı
  static const double powerUpDuration = 10.0;
  static const int baseSpawnDelay = 2000;

  static double getEnemySpeed(int level) {
    return baseEnemySpeed + (level * 0.5);
  }

  static double getMeteorSpeed(int level) {
    return baseMeteorSpeed + (level * 0.3);
  }

  static int getSpawnDelay(int level) {
    return (baseSpawnDelay / (1 + level * 0.2)).toInt();
  }
}

class _CosmicShooterState extends State<CosmicShooter>
    with TickerProviderStateMixin {
  // Screen and game state
  late Size screenSize;
  late GameState gameState;

  // Game objects
  late GameObject player;
  List<GameObject> enemies = [];
  List<GameObject> meteors = [];
  List<GameObject> lasers = [];
  List<GameObject> powerUps = [];
  List<GameObject> explosions = [];

  // Timers and controllers
  Timer? gameTimer;
  Timer? enemySpawnTimer;
  Timer? meteorSpawnTimer;
  Timer? powerUpSpawnTimer;
  late AnimationController explosionController;

  // Game settings
  double sensitivity = 1.0;
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    gameState = GameState();
    _initializeAnimations();
    _loadSettings();
    _loadHighScore();
  }

  void _gameLoop(Timer timer) {
    if (!gameState.isPlaying || gameState.isPaused) return;

    final now = DateTime.now();
    final dt = now.difference(gameState.lastUpdateTime).inMilliseconds / 1000.0;
    gameState.lastUpdateTime = now;

    setState(() {
      _updateGameObjects(dt);
      _checkCollisions();
      _cleanupObjects();
      _checkLevelProgress();
    });
  }

  // _CosmicShooterState sınıfına eklenecek metodlar:

  void _initializeAnimations() {
    explosionController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    explosionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          explosions.removeWhere(
              (explosion) => explosion.position == explosions.first.position);
        });
        explosionController.reset();
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      soundEnabled = prefs.getBool('soundEnabled') ?? true;
      musicEnabled = prefs.getBool('musicEnabled') ?? true;
      vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      sensitivity = prefs.getDouble('sensitivity') ?? 1.0;
    });
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      gameState.highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', gameState.highScore);
  }

  void _cleanupObjects() {
    setState(() {
      lasers.removeWhere(
          (laser) => laser.position.dy < -laser.size.height || !laser.isActive);

      enemies.removeWhere((enemy) =>
          enemy.position.dy > screenSize.height + enemy.size.height ||
          !enemy.isActive);

      meteors.removeWhere((meteor) =>
          meteor.position.dy > screenSize.height + meteor.size.height ||
          meteor.position.dx < -meteor.size.width ||
          meteor.position.dx > screenSize.width + meteor.size.width ||
          !meteor.isActive);

      powerUps.removeWhere((powerUp) =>
          powerUp.position.dy > screenSize.height + powerUp.size.height ||
          !powerUp.isActive);
    });
  }

  void _checkBoundaries(GameObject object) {
    object.position = Offset(
      object.position.dx.clamp(0, screenSize.width - object.size.width),
      object.position.dy.clamp(0, screenSize.height - object.size.height),
    );
  }

  void _createExplosion(Offset position) {
    setState(() {
      explosions.add(GameObject(
        type: GameObjectType.explosion,
        position: position,
        size: Size(60, 60),
        speed: 0,
        color: Colors.orange,
      ));
    });
    explosionController.forward(from: 0.0);
  }

  void _gameOver() {
    gameState.isPlaying = false;
    if (gameState.score > gameState.highScore) {
      gameState.highScore = gameState.score;
      _saveHighScore();
    }
    _showGameOverDialog();
  }

  void _pauseGame() {
    setState(() {
      gameState.isPaused = true;
      _showPauseMenu();
    });
  }

  void _resumeGame() {
    setState(() {
      gameState.isPaused = false;
    });
  }

  void _resetGame() {
    setState(() {
      gameState.reset();

      // Nesneleri temizle
      enemies.clear();
      meteors.clear();
      lasers.clear();
      powerUps.clear();
      explosions.clear();

      // Oyuncuyu başlangıç pozisyonuna getir
      player.position = Offset(
        screenSize.width / 2,
        screenSize.height - 100,
      );

      // Timer'ları iptal et
      _cancelTimers();
    });
  }

  void _startGame() {
    setState(() {
      gameState.isPlaying = true;
      gameState.isPaused = false;
      _initializeGame();
    });
  }
  // _CosmicShooterState sınıfına eklenecek son metodlar:

  void _initializeGame() {
    screenSize = MediaQuery.of(context).size;

    // Oyuncu gemisini ekranın ortasında başlat
    player = GameObject(
      type: GameObjectType.player,
      position: Offset(
        screenSize.width / 2 - 30, // Geminin boyutunun yarısı kadar sola kaydır
        screenSize.height * 0.6, // Ekranın %60'ında başlat
      ),
      size: Size(60, 60),
      speed: GameConfig.playerBaseSpeed,
      color: Colors.blue,
    );

    // Timer'ları başlat
    gameTimer = Timer.periodic(Duration(milliseconds: 16), _gameLoop);
    _resetSpawnTimers();
  }

  void _showHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    final scores = (prefs.getStringList('highScores') ?? [])
        .map((s) => int.parse(s))
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HIGH SCORES',
                style: GoogleFonts.orbitron(
                  color: Colors.amber,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 20),
              ...scores.take(5).map((score) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      score.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  )),
              if (scores.isEmpty)
                Text(
                  'No scores yet!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'CLOSE',
                  style: GoogleFonts.orbitron(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _spawnPowerUp() {
    if (!gameState.isPlaying || gameState.isPaused) return;

    final random = Random();
    final powerUpType =
        PowerUpType.values[random.nextInt(PowerUpType.values.length)];

    setState(() {
      powerUps.add(GameObject(
        type: GameObjectType.powerUp,
        position: Offset(
          random.nextDouble() * (screenSize.width - 30),
          -50,
        ),
        size: Size(30, 30),
        speed: 2,
        color: _getPowerUpColor(powerUpType),
        powerUpType: powerUpType,
      ));
    });
  }

  Color _getPowerUpColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Colors.cyan;
      case PowerUpType.doubleLaser:
        return Colors.purple;
      case PowerUpType.speedBoost:
        return Colors.yellow;
    }
  }

  void _quitGame() {
    _resetGame();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GoldenAceHome()),
    );
  }

  IconData _getPowerUpIcon(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return Icons.shield;
      case PowerUpType.doubleLaser:
        return Icons.flash_on;
      case PowerUpType.speedBoost:
        return Icons.speed;
    }
  }

  Widget _buildMainMenu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'COSMIC\nSHOOTER',
            style: GoogleFonts.orbitron(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.blue,
                  blurRadius: 10,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 50),
          _buildMenuButton(
            'START GAME',
            Icons.play_arrow,
            () {
              _startGame();
            },
          ),
          SizedBox(height: 20),
          _buildMenuButton(
            'HIGH SCORES',
            Icons.emoji_events,
            () => _showHighScores(),
          ),
          SizedBox(height: 20),
          _buildMenuButton(
            'EXIT GAME',
            Icons.emoji_events,
            () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _cancelTimers() {
    gameTimer?.cancel();
    enemySpawnTimer?.cancel();
    meteorSpawnTimer?.cancel();
    powerUpSpawnTimer?.cancel();
  }

  Widget _buildPauseMenu() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PAUSED',
              style: GoogleFonts.orbitron(
                color: Colors.amber,
                fontSize: 28,
              ),
            ),
            SizedBox(height: 20),
            _buildMenuButton(
              'RESUME',
              Icons.play_arrow,
              _resumeGame,
            ),
            SizedBox(height: 10),
            _buildMenuButton(
              'RESTART',
              Icons.refresh,
              () {
                _resetGame();
                _startGame();
              },
            ),
            SizedBox(height: 10),
            _buildMenuButton(
              'QUIT',
              Icons.exit_to_app,
              _quitGame,
            ),
          ],
        ),
      ),
    );
  }

  void _moveObjects() {
    final dt = 1.0 / 60.0; // Sabit delta time

    // Lazerler
    for (var laser in lasers.where((l) => l.isActive)) {
      laser.update(dt);
    }

    // Düşmanlar
    for (var enemy in enemies.where((e) => e.isActive)) {
      enemy.speed = GameConfig.getEnemySpeed(gameState.level);
      enemy.update(dt);
    }

    // Meteorlar
    for (var meteor in meteors.where((m) => m.isActive)) {
      meteor.speed = GameConfig.getMeteorSpeed(gameState.level);
      meteor.update(dt);
    }

    // Power-up'lar
    for (var powerUp in powerUps.where((p) => p.isActive)) {
      powerUp.update(dt);
    }
  }

  void _updateGameObjects(double dt) {
    // Update player movement with sensitivity
    if (player.isActive) {
      player.update(dt * sensitivity);
      _checkBoundaries(player);
    }

    // Update lasers
    for (var laser in lasers) {
      if (laser.isActive) {
        laser.update(dt);
      }
    }

    // Update enemies with level-based speed
    for (var enemy in enemies) {
      if (enemy.isActive) {
        enemy.speed = GameConfig.getEnemySpeed(gameState.level);
        enemy.update(dt);
      }
    }

    // Update meteors with physics
    for (var meteor in meteors) {
      if (meteor.isActive) {
        meteor.speed = GameConfig.getMeteorSpeed(gameState.level);
        // Add sine wave movement
        meteor.position = Offset(
            meteor.position.dx + sin(meteor.position.dy / 30) * 2 * dt,
            meteor.position.dy + meteor.speed * dt);
      }
    }

    // Update power-ups
    for (var powerUp in powerUps) {
      if (powerUp.isActive) {
        powerUp.update(dt);
      }
    }
  }

  void _checkCollisions() {
    // Player collision checks
    if (player.isActive && !gameState.hasShield) {
      // Check enemy collisions
      for (var enemy in enemies.where((e) => e.isActive)) {
        if (player.collidesWith(enemy)) {
          _damagePlayer(20);
          enemy.isActive = false;
          _createExplosion(enemy.position);
        }
      }

      // Check meteor collisions
      for (var meteor in meteors.where((m) => m.isActive)) {
        if (player.collidesWith(meteor)) {
          _damagePlayer(10);
          meteor.isActive = false;
          _createExplosion(meteor.position);
        }
      }
    }

    // Laser collision checks
    for (var laser in lasers.where((l) => l.isActive)) {
      // Check laser-enemy collisions
      for (var enemy in enemies.where((e) => e.isActive)) {
        if (laser.collidesWith(enemy)) {
          laser.isActive = false;
          enemy.isActive = false;
          _createExplosion(enemy.position);
          gameState.score += 10;
        }
      }

      // Check laser-meteor collisions
      for (var meteor in meteors.where((m) => m.isActive)) {
        if (laser.collidesWith(meteor)) {
          laser.isActive = false;
          meteor.isActive = false;
          _createExplosion(meteor.position);
          gameState.score += 5;
        }
      }
    }

    // Power-up collision checks
    for (var powerUp in powerUps.where((p) => p.isActive)) {
      if (player.collidesWith(powerUp)) {
        _activatePowerUp(powerUp.powerUpType!);
        powerUp.isActive = false;
      }
    }
  }

  void _activatePowerUp(PowerUpType type) {
    setState(() {
      switch (type) {
        case PowerUpType.shield:
          gameState.hasShield = true;
          Future.delayed(Duration(seconds: GameConfig.powerUpDuration.toInt()),
              () {
            if (mounted) {
              setState(() => gameState.hasShield = false);
            }
          });
          break;

        case PowerUpType.doubleLaser:
          gameState.hasDoubleLaser = true;
          Future.delayed(Duration(seconds: GameConfig.powerUpDuration.toInt()),
              () {
            if (mounted) {
              setState(() => gameState.hasDoubleLaser = false);
            }
          });
          break;

        case PowerUpType.speedBoost:
          gameState.hasSpeedBoost = true;
          player.speed *= 1.5;
          Future.delayed(Duration(seconds: GameConfig.powerUpDuration.toInt()),
              () {
            if (mounted) {
              setState(() {
                gameState.hasSpeedBoost = false;
                player.speed /= 1.5;
              });
            }
          });
          break;
      }
    });
  }

  void _damagePlayer(double damage) {
    setState(() {
      gameState.playerHealth -= damage;
      if (gameState.playerHealth <= 0) {
        _gameOver();
      }
    });
  }

  void _checkLevelProgress() {
    if (gameState.score >= gameState.level * 1000) {
      setState(() {
        gameState.level++;
        _showLevelUpDialog();
        _updateDifficulty();
      });
    }
  }

  void _updateDifficulty() {
    // Update spawn timers based on level
    _resetSpawnTimers();

    // Update enemy and meteor speeds handled in _updateGameObjects
  }

  void _resetSpawnTimers() {
    enemySpawnTimer?.cancel();
    meteorSpawnTimer?.cancel();
    powerUpSpawnTimer?.cancel();

    final spawnDelay = GameConfig.getSpawnDelay(gameState.level);

    enemySpawnTimer = Timer.periodic(
        Duration(milliseconds: spawnDelay), (timer) => _spawnEnemy());

    meteorSpawnTimer = Timer.periodic(
        Duration(milliseconds: spawnDelay * 2), (timer) => _spawnMeteor());

    powerUpSpawnTimer =
        Timer.periodic(Duration(seconds: 10), (timer) => _spawnPowerUp());
  }

  // Önceki _CosmicShooterState sınıfının devamı...

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
      body: WillPopScope(
        onWillPop: () async {
          if (gameState.isPlaying) {
            _pauseGame();
            return false;
          }
          return true;
        },
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/space.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Game Objects Layer
                if (gameState.isPlaying) ...[
                  _buildGameObjects(),
                  _buildHUD(),
                  if (gameState.isPaused) _buildPauseMenu(),
                ] else ...[
                  _buildMainMenu(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameObjects() {
    return GestureDetector(
      onPanUpdate: (details) {
        if (!gameState.isPlaying || gameState.isPaused) return;
        setState(() {
          player.position = Offset(
            player.position.dx + details.delta.dx * sensitivity,
            player.position.dy + details.delta.dy * sensitivity,
          );
          _checkBoundaries(player);
        });
      },
      onTapDown: (details) => _fireLaser(),
      child: Stack(
        children: [
          // Player
          if (player.isActive)
            _buildGameObject(
              player,
              child: CustomPaint(
                painter: SpaceshipPainter(hasShield: gameState.hasShield),
              ),
            ),

          // Lasers
          ...lasers.where((laser) => laser.isActive).map(
                (laser) => _buildGameObject(
                  laser,
                  decoration: BoxDecoration(
                    color: laser.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: laser.color.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

          // Enemies
          ...enemies.where((enemy) => enemy.isActive).map(
                (enemy) => _buildGameObject(
                  enemy,
                  child: Transform.rotate(
                    angle: pi,
                    child: CustomPaint(
                      painter: EnemyShipPainter(),
                    ),
                  ),
                ),
              ),

          // Meteors
          ...meteors.where((meteor) => meteor.isActive).map(
                (meteor) => _buildGameObject(
                  meteor,
                  child: CustomPaint(
                    painter: MeteorPainter(),
                  ),
                ),
              ),

          // Power-ups
          ...powerUps.where((powerUp) => powerUp.isActive).map(
                (powerUp) => _buildGameObject(
                  powerUp,
                  decoration: BoxDecoration(
                    color: powerUp.color.withOpacity(0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: powerUp.color.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getPowerUpIcon(powerUp.powerUpType!),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),

          // Explosions
          ...explosions.map(
            (explosion) => _buildExplosion(explosion),
          ),
        ],
      ),
    );
  }

  Widget _buildGameObject(
    GameObject object, {
    Widget? child,
    BoxDecoration? decoration,
  }) {
    return Positioned(
      left: object.position.dx,
      top: object.position.dy,
      child: Transform.rotate(
        angle: object.rotation,
        child: Container(
          width: object.size.width,
          height: object.size.height,
          decoration: decoration,
          child: child,
        ),
      ),
    );
  }

  Widget _buildExplosion(GameObject explosion) {
    return Positioned(
      left: explosion.position.dx,
      top: explosion.position.dy,
      child: AnimatedBuilder(
        animation: explosionController,
        builder: (context, child) {
          return Container(
            width: explosion.size.width * explosionController.value,
            height: explosion.size.height * explosionController.value,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.yellow,
                  Colors.orange,
                  Colors.red.withOpacity(0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score and Level
          Text(
            'Score: ${gameState.score}\nLevel: ${gameState.level}',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 20,
            ),
          ),

          // Health Bar
          Container(
            width: 150,
            height: 20,
            margin: EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: gameState.playerHealth / 100,
                backgroundColor: Colors.red[900],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),

          // Power-up Indicators
          if (gameState.hasShield ||
              gameState.hasDoubleLaser ||
              gameState.hasSpeedBoost)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (gameState.hasShield)
                    _buildPowerUpIndicator(Icons.shield, Colors.cyan),
                  if (gameState.hasDoubleLaser)
                    _buildPowerUpIndicator(Icons.flash_on, Colors.purple),
                  if (gameState.hasSpeedBoost)
                    _buildPowerUpIndicator(Icons.speed, Colors.yellow),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPowerUpIndicator(IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _spawnEnemy() {
    if (!gameState.isPlaying || gameState.isPaused) return;

    final random = Random();
    final enemyWidth = 40.0;

    setState(() {
      enemies.add(GameObject(
        type: GameObjectType.enemy,
        position: Offset(
          random.nextDouble() * (screenSize.width - enemyWidth),
          -50,
        ),
        size: Size(enemyWidth, enemyWidth),
        speed: GameConfig.getEnemySpeed(gameState.level),
        color: Colors.red,
        rotation: pi,
        health: 100,
      ));
    });
  }

  void _spawnMeteor() {
    if (!gameState.isPlaying || gameState.isPaused) return;

    final random = Random();
    final meteorWidth = 30.0;

    setState(() {
      meteors.add(GameObject(
        type: GameObjectType.meteor,
        position: Offset(
          random.nextDouble() * (screenSize.width - meteorWidth),
          -50,
        ),
        size: Size(meteorWidth, meteorWidth),
        speed: GameConfig.getMeteorSpeed(gameState.level),
        color: Colors.brown,
        rotation: random.nextDouble() * 2 * pi,
        health: 50,
      ));
    });
  }

  // _fireLaser metodunu güncelle
  void _fireLaser() {
    if (!gameState.isPlaying || gameState.isPaused) return;

    setState(() {
      final laserWidth = 4.0;
      final laserHeight = 20.0; // Mermi boyutu arttırıldı

      final positions = gameState.hasDoubleLaser
          ? [
              Offset(player.position.dx - 10, player.position.dy),
              Offset(player.position.dx + player.size.width - 10,
                  player.position.dy),
            ]
          : [
              Offset(player.position.dx + (player.size.width - laserWidth) / 2,
                  player.position.dy)
            ];

      for (var position in positions) {
        lasers.add(GameObject(
          type: GameObjectType.laser,
          position: position,
          size: Size(laserWidth, laserHeight),
          speed: GameConfig.baseLaserSpeed,
          color: Colors.greenAccent, // Renk daha parlak yapıldı
          rotation: -pi / 2,
        ));
      }
    });
  }
}

// SpaceshipPainter sınıfını güncelle
class SpaceshipPainter extends CustomPainter {
  final bool hasShield;

  SpaceshipPainter({this.hasShield = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue[700]!, Colors.blue[300]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Daha belirgin gemi gövdesi
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.7, size.height * 0.8)
      ..lineTo(size.width * 0.3, size.height * 0.8)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Motor efekti
    final enginePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.blue[300]!, Colors.blue[700]!.withOpacity(0)],
        center: Alignment.bottomCenter,
      ).createShader(
          Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2));

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, size.height * 0.7, size.width * 0.4,
          size.height * 0.3),
      enginePaint,
    );

    if (hasShield) {
      final shieldPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.cyan.withOpacity(0.3), Colors.cyan.withOpacity(0.1)],
          stops: [0.8, 1.0],
        ).createShader(Rect.fromLTWH(-size.width * 0.5, -size.height * 0.5,
            size.width * 2, size.height * 2));

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width * 0.8,
        shieldPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SpaceshipPainter oldDelegate) =>
      hasShield != oldDelegate.hasShield;
}

class EnemyShipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.red[700]!, Colors.red[300]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Düşman gemisi detayları
    final detailPaint = Paint()..color = Colors.red[900]!;

    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, size.height * 0.3, size.width * 0.4,
          size.height * 0.4),
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(EnemyShipPainter oldDelegate) => false;
}

class MeteorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.brown[400]!, Colors.brown[800]!],
        center: Alignment(-0.2, -0.2),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Ana meteor gövdesi
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    // Krater detayları
    final craterPaint = Paint()..color = Colors.brown[900]!;

    final random = Random(42); // Sabit seed ile rastgele kraterler
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        size.width * 0.1,
        craterPaint,
      );
    }
  }

  @override
  bool shouldRepaint(MeteorPainter oldDelegate) => false;
}

// Dialog sistemleri
extension GameDialogs on _CosmicShooterState {
  void _showPauseMenu() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow),
          ),
          title: Text(
            'PAUSED',
            style: GoogleFonts.orbitron(
              color: Colors.amber,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuButton(
                'RESUME',
                Icons.play_arrow,
                () {
                  Navigator.pop(context);
                  _resumeGame();
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                'RESTART',
                Icons.refresh,
                () {
                  Navigator.pop(context);
                  _resetGame();
                  _startGame();
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                'QUIT',
                Icons.exit_to_app,
                () {
                  Navigator.pop(context);
                  _quitGame();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 200,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          text,
          style: GoogleFonts.orbitron(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog() {
    if (gameState.score > gameState.highScore) {
      gameState.highScore = gameState.score;
      _saveHighScore();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red),
        ),
        title: Text(
          'GAME OVER',
          style: GoogleFonts.orbitron(
            color: Colors.red,
            fontSize: 28,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: ${gameState.score}',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              'High Score: ${gameState.highScore}',
              style: TextStyle(color: Colors.amber, fontSize: 20),
            ),
            SizedBox(height: 20),
            _buildMenuButton(
              'PLAY AGAIN',
              Icons.replay,
              () {
                Navigator.pop(context);
                _resetGame();
                _startGame();
              },
            ),
            SizedBox(height: 10),
            _buildMenuButton(
              'QUIT',
              Icons.exit_to_app,
              () {
                Navigator.pop(context);
                _quitGame();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber),
        ),
        title: Text(
          'LEVEL UP!',
          style: GoogleFonts.orbitron(
            color: Colors.amber,
            fontSize: 28,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Level ${gameState.level} Complete!',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            SizedBox(height: 10),
            Text(
              'Get ready for more challenges!',
              style: TextStyle(color: Colors.amber, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            _buildMenuButton(
              'CONTINUE',
              Icons.arrow_forward,
              () {
                Navigator.pop(context);
                setState(() {
                  _updateDifficulty();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Main uygulama ve oyun başlatma
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(MaterialApp(
    title: 'Cosmic Shooter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.purple,
      scaffoldBackgroundColor: Colors.black,
      textTheme: GoogleFonts.orbitronTextTheme(
        ThemeData.dark().textTheme,
      ),
    ),
    home: const CosmicShooter(),
  ));
}
