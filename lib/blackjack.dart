import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

// Oyun parçaları için enum
enum GalacticPiece {
  planet1,
  planet2,
  planet3,
  star,
  comet,
  blackHole,
  nebula,
  asteroid
}

// Power-up sınıfı
class GalacticPowerUp {
  final String name;
  final String description;
  final IconData icon;
  final int cost;
  final Duration duration;
  bool isActive;
  Timer? activeTimer;

  GalacticPowerUp({
    required this.name,
    required this.description,
    required this.icon,
    required this.cost,
    required this.duration,
    this.isActive = false,
  });
}

class GalacticMatch extends StatefulWidget {
  const GalacticMatch({Key? key}) : super(key: key);

  @override
  _GalacticMatchState createState() => _GalacticMatchState();
}

class _GalacticMatchState extends State<GalacticMatch>
    with TickerProviderStateMixin {
  // Oyun durumu değişkenleri
  int crystals = 1000;
  int score = 0;
  int comboCount = 0;
  int maxCombo = 0;
  double energyLevel = 0;
  double maxEnergy = 100;
  bool isPlaying = false;
  int currentLevel = 1;
  int targetScore = 100;
  bool showingLevelComplete = false;

  // Oyun tahtası
  static const int rows = 6;
  static const int cols = 4;
  late List<List<GalacticPiece>> board;
  List<List<bool>> selected = List.generate(
    rows,
    (i) => List.generate(cols, (j) => false),
  );

  // Animasyon kontrolcüleri
  late AnimationController energyController;
  late Animation<double> energyAnimation;

  // Power-up'lar
  late List<GalacticPowerUp> powerUps;

  @override
  void initState() {
    super.initState();
    _initializePowerUps();
    _initializeGame();
    _startEnergyTimer();
    _setupAnimations();
    _loadGameData();
  }

  void _initializePowerUps() {
    powerUps = [
      GalacticPowerUp(
        name: 'Time Freeze',
        description: 'Freeze the board for 30 seconds',
        icon: Icons.ac_unit,
        cost: 100,
        duration: Duration(seconds: 30),
      ),
      GalacticPowerUp(
        name: 'Cosmic Ray',
        description: 'Clear an entire row',
        icon: Icons.flash_on,
        cost: 200,
        duration: Duration(seconds: 10),
      ),
      GalacticPowerUp(
        name: 'Gravity Well',
        description: 'Pull matching pieces together',
        icon: Icons.blur_circular,
        cost: 150,
        duration: Duration(seconds: 15),
      ),
    ];
  }

  void _setupAnimations() {
    energyController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    energyAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: energyController,
        curve: Curves.easeInOut,
      ),
    );

    energyController.repeat(reverse: true);
  }

  // Oyun başlatma mantığını düzeltelim:
  void _initializeGame() {
    setState(() {
      isPlaying = true;
      score = 0;
      comboCount = 0;
      energyLevel = maxEnergy;
      board = List.generate(
        rows,
        (i) => List.generate(
          cols,
          (j) => _getRandomPiece(),
        ),
      );
      _ensureNoInitialMatches();

      // Seçimleri sıfırla
      selected = List.generate(
        rows,
        (i) => List.generate(cols, (j) => false),
      );
    });
  }

  GalacticPiece _getRandomPiece() {
    return GalacticPiece.values[Random().nextInt(GalacticPiece.values.length)];
  }

  void _ensureNoInitialMatches() {
    bool hasMatches;
    do {
      hasMatches = false;
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          if (_checkMatch(i, j)) {
            board[i][j] = _getRandomPiece();
            hasMatches = true;
          }
        }
      }
    } while (hasMatches);
  }

  void _startEnergyTimer() {
    Timer.periodic(Duration(seconds: 3), (timer) {
      if (!isPlaying && energyLevel < maxEnergy) {
        setState(() {
          energyLevel = min(maxEnergy, energyLevel + 2);
        });
      }
    });
  }

  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      maxCombo = prefs.getInt('galactic_maxCombo') ?? 0;
      energyLevel = (prefs.getInt('galactic_energy') ?? 50).toDouble();
      crystals = prefs.getInt('galactic_crystals') ?? 1000;
      score = prefs.getInt('galactic_score') ?? 0;
      currentLevel = prefs.getInt('galactic_level') ?? 1;
      targetScore = 100 + ((currentLevel - 1) * 50);
    });
  }

  void _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('galactic_maxCombo', maxCombo);
    await prefs.setInt('galactic_energy', energyLevel.toInt());
    await prefs.setInt('galactic_crystals', crystals);
    await prefs.setInt('galactic_score', score);
    await prefs.setInt('galactic_level', currentLevel);
  }

  bool _checkMatch(int row, int col) {
    final piece = board[row][col];
    int horizontal = 1;
    int vertical = 1;

    // Check horizontal matches
    for (int i = col + 1; i < cols && board[row][i] == piece; i++) {
      horizontal++;
    }
    for (int i = col - 1; i >= 0 && board[row][i] == piece; i--) {
      horizontal++;
    }

    // Check vertical matches
    for (int i = row + 1; i < rows && board[i][col] == piece; i++) {
      vertical++;
    }
    for (int i = row - 1; i >= 0 && board[i][col] == piece; i--) {
      vertical++;
    }

    return horizontal >= 3 || vertical >= 3;
  }

  // _onTileTap fonksiyonunu düzeltelim:
  void _onTileTap(int row, int col) {
    if (!isPlaying) return;

    setState(() {
      bool hasSelection = selected.any((row) => row.any((cell) => cell));

      if (hasSelection) {
        int selectedRow = -1;
        int selectedCol = -1;

        for (int i = 0; i < rows; i++) {
          for (int j = 0; j < cols; j++) {
            if (selected[i][j]) {
              selectedRow = i;
              selectedCol = j;
              break;
            }
          }
        }

        if (selectedRow != -1) {
          if (_isAdjacent(selectedRow, selectedCol, row, col)) {
            _swapTiles(selectedRow, selectedCol, row, col);
          }

          // Her durumda seçimi temizle
          selected = List.generate(
            rows,
            (i) => List.generate(cols, (j) => false),
          );
        }
      } else {
        selected[row][col] = true;
      }
    });
  }

  bool _isAdjacent(int row1, int col1, int row2, int col2) {
    return (row1 == row2 && (col1 == col2 - 1 || col1 == col2 + 1)) ||
        (col1 == col2 && (row1 == row2 - 1 || row1 == row2 + 1));
  }

  Future<void> _swapTiles(int row1, int col1, int row2, int col2) async {
    setState(() {
      final temp = board[row1][col1];
      board[row1][col1] = board[row2][col2];
      board[row2][col2] = temp;
    });

    if (!_checkForMatches()) {
      // Swap back if no matches
      await Future.delayed(Duration(milliseconds: 300));
      setState(() {
        final temp = board[row1][col1];
        board[row1][col1] = board[row2][col2];
        board[row2][col2] = temp;
      });
    } else {
      _handleMatches();
    }
  }

  bool _checkForMatches() {
    bool hasMatches = false;
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (_checkMatch(i, j)) {
          hasMatches = true;
          break;
        }
      }
      if (hasMatches) break;
    }
    return hasMatches;
  }

  // _handleMatches fonksiyonunu güncelleyelim
  void _handleMatches() {
    List<List<bool>> matched = List.generate(
      rows,
      (i) => List.generate(cols, (j) => false),
    );

    // Mark matches
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (_checkMatch(i, j)) {
          _markMatches(i, j, matched);
        }
      }
    }

    // Remove matches and update score
    int matchCount = 0;
    setState(() {
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          if (matched[i][j]) {
            matchCount++;
            board[i][j] = _getRandomPiece();
          }
        }
      }

      if (matchCount > 0) {
        _updateScore(matchCount);
        comboCount++;
        if (comboCount > maxCombo) maxCombo = comboCount;
        energyLevel = min(maxEnergy, energyLevel + matchCount.toDouble());
      } else {
        comboCount = 0;
      }
    });

    // Check for cascading matches
    if (_checkForMatches()) {
      Future.delayed(Duration(milliseconds: 500), _handleMatches);
    } else {
      // Hamle kontrolü yap
      _checkBoardState();
    }
  }

  void _markMatches(int row, int col, List<List<bool>> matched) {
    final piece = board[row][col];

    // Mark horizontal matches
    int right = 0;
    for (int j = col; j < cols && board[row][j] == piece; j++) {
      right++;
    }

    int left = 0;
    for (int j = col; j >= 0 && board[row][j] == piece; j--) {
      left++;
    }

    if (left + right - 1 >= 3) {
      for (int j = col - left + 1; j < col + right; j++) {
        matched[row][j] = true;
      }
    }

    // Mark vertical matches
    int down = 0;
    for (int i = row; i < rows && board[i][col] == piece; i++) {
      down++;
    }

    int up = 0;
    for (int i = row; i >= 0 && board[i][col] == piece; i--) {
      up++;
    }

    if (up + down - 1 >= 3) {
      for (int i = row - up + 1; i < row + down; i++) {
        matched[i][col] = true;
      }
    }
  }

  void _updateScore(int matchCount) {
    setState(() {
      score += matchCount * 10 * (comboCount + 1);
      _checkLevelComplete();
    });
  }

  void _checkLevelComplete() {
    if (score >= targetScore && !showingLevelComplete) {
      showingLevelComplete = true;
      _showLevelCompleteDialog();
    }
  }

  void _showInsufficientFundsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Insufficient Crystals',
                style: GoogleFonts.russoOne(
                  fontSize: 24,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Icon(Icons.error_outline, color: Colors.white, size: 50),
              SizedBox(height: 16),
              Text(
                'You don\'t have enough crystals!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.russoOne(fontSize: 16),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPowerUpActivatedDialog(GalacticPowerUp powerUp) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Power-Up Activated!',
                style: GoogleFonts.russoOne(
                  color: Colors.amber,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Icon(powerUp.icon, color: Colors.amber, size: 50),
              SizedBox(height: 16),
              Text(
                powerUp.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                powerUp.description,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Duration: ${powerUp.duration.inSeconds} seconds',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.russoOne(fontSize: 16),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to Play',
                style: GoogleFonts.russoOne(
                  color: Colors.amber,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                '• Match 3 or more similar pieces\n'
                '• Create combos for bonus points\n'
                '• Use power-ups strategically\n'
                '• Fill energy bar for special rewards\n'
                '• Complete levels to progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Got it!',
                  style: GoogleFonts.russoOne(fontSize: 16),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPowerUpCard(GalacticPowerUp powerUp) {
    return Container(
      width: 80,
      height: 80, // Sabit yükseklik belirliyoruz
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: powerUp.isActive
            ? Colors.purpleAccent.withOpacity(0.3)
            : Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: powerUp.isActive ? Colors.amber : Colors.purpleAccent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _activatePowerUp(powerUp),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.min, // min olarak değiştirdik
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // spacing'i değiştirdik
                  children: [
                    Icon(
                      powerUp.icon,
                      color: powerUp.isActive ? Colors.amber : Colors.white70,
                      size: constraints.maxHeight * 0.3, // Dinamik boyut
                    ),
                    Container(
                      height: constraints.maxHeight * 0.3, // Dinamik yükseklik
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          powerUp.name,
                          style: TextStyle(
                            color: powerUp.isActive
                                ? Colors.amber
                                : Colors.white70,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    Container(
                      height: constraints.maxHeight * 0.2, // Dinamik yükseklik
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${powerUp.cost}',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

// PowerUp kartlarını içeren container'ı da güncelleyelim
  Widget _buildControls() {
    return Container(
      color: Colors.black87,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 80, // PowerUp kartlarıyla aynı yükseklik
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: powerUps.length,
              itemBuilder: (context, index) =>
                  _buildPowerUpCard(powerUps[index]),
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: !isPlaying
                    ? () {
                        setState(() {
                          _initializeGame();
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isPlaying ? 'PLAYING' : 'START',
                  style: GoogleFonts.russoOne(fontSize: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Power-up aktivasyonunu düzeltelim:
  void _activatePowerUp(GalacticPowerUp powerUp) {
    if (!isPlaying || powerUp.isActive || crystals < powerUp.cost) {
      if (crystals < powerUp.cost) {
        _showInsufficientFundsDialog();
      }
      return;
    }

    setState(() {
      crystals -= powerUp.cost;
      powerUp.isActive = true;
    });

    // Power-up efektlerini uygula
    switch (powerUp.name) {
      case 'Time Freeze':
        //    _applyTimeFreeze();
        break;
      case 'Cosmic Ray':
        _applyCosmicRay();
        break;
      case 'Gravity Well':
        _applyGravityWell();
        break;
    }

    powerUp.activeTimer?.cancel();
    powerUp.activeTimer = Timer(powerUp.duration, () {
      if (mounted) {
        setState(() {
          powerUp.isActive = false;
        });
      }
    });

    _showPowerUpActivatedDialog(powerUp);
  }

  void _applyCosmicRay() {
    final randomRow = Random().nextInt(rows);
    setState(() {
      for (int j = 0; j < cols; j++) {
        board[randomRow][j] = _getRandomPiece();
      }
      score += cols * 10;
      energyLevel = min(maxEnergy, energyLevel + cols.toDouble());
    });
  }

  void _applyGravityWell() {
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (_checkMatch(i, j)) {
          _handleMatches();
          break;
        }
      }
    }
  }

// Mevcut board'da yapılabilecek hamle var mı kontrol eden fonksiyon
  bool _hasValidMoves() {
    // Yatay kontrol
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols - 1; j++) {
        // Komşu parçaları geçici olarak değiştir ve eşleşme var mı kontrol et
        _swapPieces(i, j, i, j + 1);
        if (_checkForMatches()) {
          _swapPieces(i, j, i, j + 1); // Geri al
          return true;
        }
        _swapPieces(i, j, i, j + 1); // Geri al
      }
    }

    // Dikey kontrol
    for (int i = 0; i < rows - 1; i++) {
      for (int j = 0; j < cols; j++) {
        _swapPieces(i, j, i + 1, j);
        if (_checkForMatches()) {
          _swapPieces(i, j, i + 1, j); // Geri al
          return true;
        }
        _swapPieces(i, j, i + 1, j); // Geri al
      }
    }

    return false;
  }

// Board'u karıştıran fonksiyon
  void _shuffleBoard() {
    final random = Random();

    // Board'u karıştır
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        int newI = random.nextInt(rows);
        int newJ = random.nextInt(cols);

        // Parçaları değiştir
        var temp = board[i][j];
        board[i][j] = board[newI][newJ];
        board[newI][newJ] = temp;
      }
    }

    // Eğer başlangıçta eşleşme varsa tekrar karıştır
    while (_checkForMatches()) {
      _shuffleBoard();
    }

    // Karıştırma sonrası hala geçerli hamle yoksa, bazı parçaları değiştir
    if (!_hasValidMoves()) {
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          board[i][j] = _getRandomPiece();
        }
      }
      _ensureNoInitialMatches();
    }
  }

// Parçaları değiştiren yardımcı fonksiyon
  void _swapPieces(int row1, int col1, int row2, int col2) {
    var temp = board[row1][col1];
    board[row1][col1] = board[row2][col2];
    board[row2][col2] = temp;
  }

  // Her hamleden sonra kontrol yapacak fonksiyon
  void _checkBoardState() {
    if (!_hasValidMoves()) {
      // Kullanıcıya bilgi ver
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.purple[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'No Moves Available!',
            style: GoogleFonts.russoOne(color: Colors.amber),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Shuffling the board...',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.russoOne(),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _shuffleBoard();
                  });
                },
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/deep_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildEnergyAndStats(),
              Expanded(
                child: _buildGameBoard(),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return Expanded(
      // Expanded ekledik
      child: Center(
        child: LayoutBuilder(
          // LayoutBuilder ekledik
          builder: (context, constraints) {
            double tileSize = min(
              constraints.maxWidth / cols,
              constraints.maxHeight / rows,
            );
            return SizedBox(
              width: tileSize * cols,
              height: tileSize * rows,
              child: GridView.builder(
                padding: EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: rows * cols,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final row = index ~/ cols;
                  final col = index % cols;
                  return _buildTile(row, col);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(int row, int col) {
    final piece = board[row][col];
    final isSelected = selected[row][col];

    IconData icon;
    Color color;

    switch (piece) {
      case GalacticPiece.planet1:
        icon = Icons.circle;
        color = Colors.blue;
        break;
      case GalacticPiece.planet2:
        icon = Icons.circle;
        color = Colors.red;
        break;
      case GalacticPiece.planet3:
        icon = Icons.circle;
        color = Colors.green;
        break;
      case GalacticPiece.star:
        icon = Icons.star;
        color = Colors.yellow;
        break;
      case GalacticPiece.comet:
        icon = Icons.track_changes;
        color = Colors.orange;
        break;
      case GalacticPiece.blackHole:
        icon = Icons.blur_circular;
        color = Colors.purple;
        break;
      case GalacticPiece.nebula:
        icon = Icons.cloud;
        color = Colors.pink;
        break;
      case GalacticPiece.asteroid:
        icon = Icons.scatter_plot;
        color = Colors.brown;
        break;
    }

    return GestureDetector(
      onTap: () => _onTileTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.purpleAccent,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.transparent,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LEVEL $currentLevel',
                style: GoogleFonts.orbitron(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$score / $targetScore',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              icon: Icon(Icons.info_outline, color: Colors.white, size: 20),
              onPressed: _showInfoDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyAndStats() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purpleAccent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cosmic Energy',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      '${energyLevel.toInt()}%',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                FAProgressBar(
                  currentValue: energyLevel,
                  maxValue: maxEnergy,
                  size: 8,
                  borderRadius: BorderRadius.circular(4),
                  progressColor: Colors.purpleAccent,
                  backgroundColor: Colors.purple[900]!,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatItem(Icons.bolt, 'Combo', 'x$comboCount'),
                SizedBox(width: 8),
                _buildStatItem(Icons.emoji_events, 'Best', maxCombo.toString()),
                SizedBox(width: 8),
                _buildStatItem(Icons.diamond, 'Crystals', crystals.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber, size: 14),
          SizedBox(width: 4),
          Flexible(
            // Flexible ekledik
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                  overflow: TextOverflow.ellipsis, // Taşma kontrolü
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis, // Taşma kontrolü
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[900],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level $currentLevel Complete!',
                style: GoogleFonts.russoOne(
                  color: Colors.amber,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Icon(Icons.stars, color: Colors.amber, size: 50),
              SizedBox(height: 16),
              Text(
                'Score: $score / $targetScore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Next Level',
                  style: GoogleFonts.russoOne(fontSize: 16),
                ),
                onPressed: () {
                  setState(() {
                    currentLevel++;
                    targetScore = targetScore + (currentLevel * 50);
                    showingLevelComplete = false;
                    score = 0;
                    _initializeGame();
                    _saveGameData();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var powerUp in powerUps) {
      powerUp.activeTimer?.cancel();
    }
    energyController.dispose();
    _saveGameData();
    super.dispose();
  }

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
      title: 'Galactic Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GalacticMatch(),
    ));
  }
}
