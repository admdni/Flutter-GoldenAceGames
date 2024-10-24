import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animation_progress_bar/flutter_animation_progress_bar.dart';

class SlotSymbol {
  final IconData icon;
  final int value;
  final String name;
  final Color color;
  final bool isSpecial;

  SlotSymbol({
    required this.icon,
    required this.value,
    required this.name,
    required this.color,
    this.isSpecial = false,
  });
}

class PowerUp {
  final String name;
  final String description;
  final IconData icon;
  final int cost;
  final Duration duration;
  bool isActive;
  Timer? activeTimer;

  PowerUp({
    required this.name,
    required this.description,
    required this.icon,
    required this.cost,
    required this.duration,
    this.isActive = false,
  });
}

class CosmicSlotGame extends StatefulWidget {
  const CosmicSlotGame({Key? key}) : super(key: key);

  @override
  _CosmicSlotGameState createState() => _CosmicSlotGameState();
}

class _CosmicSlotGameState extends State<CosmicSlotGame>
    with TickerProviderStateMixin {
  int crystals = 1000;
  int betAmount = 10;
  int comboCount = 0;
  int maxCombo = 0;
  double energyLevel = 0;
  double maxEnergy = 100;
  bool isSpinning = false;
  List<List<SlotSymbol>> reels = [];
  Timer? energyTimer;
  Random random = Random();

  late List<AnimationController> spinControllers;
  late List<Animation<double>> spinAnimations;
  late AnimationController energyController;
  late Animation<double> energyAnimation;

  final List<SlotSymbol> symbols = [
    SlotSymbol(
      icon: Icons.flutter_dash,
      value: 100,
      name: 'Cosmic',
      color: Colors.blue,
      isSpecial: true,
    ),
    SlotSymbol(
      icon: Icons.star,
      value: 75,
      name: 'Star',
      color: Colors.amber,
    ),
    SlotSymbol(
      icon: Icons.attractions,
      value: 50,
      name: 'Atom',
      color: Colors.purple,
    ),
    SlotSymbol(
      icon: Icons.brightness_7,
      value: 40,
      name: 'Sun',
      color: Colors.orange,
    ),
    SlotSymbol(
      icon: Icons.radar,
      value: 30,
      name: 'Portal',
      color: Colors.green,
    ),
    SlotSymbol(
      icon: Icons.diamond,
      value: 20,
      name: 'Crystal',
      color: Colors.cyan,
    ),
  ];

  late List<PowerUp> powerUps;

  @override
  void initState() {
    super.initState();
    _initializePowerUps();
    _initializeGame();
    _startEnergyTimer();
  }

  void _initializePowerUps() {
    powerUps = [
      PowerUp(
        name: 'Energy Shield',
        description: 'Protects against losses',
        icon: Icons.shield,
        cost: 100,
        duration: Duration(minutes: 1),
      ),
      PowerUp(
        name: 'Double Crystal',
        description: 'Doubles winnings',
        icon: Icons.auto_awesome,
        cost: 200,
        duration: Duration(minutes: 2),
      ),
      PowerUp(
        name: 'Combo Boost',
        description: 'Increases combo multiplier',
        icon: Icons.flash_on,
        cost: 150,
        duration: Duration(minutes: 1),
      ),
    ];
  }

  void _initializeGame() {
    _initializeReels();
    _setupAnimations();
    _loadGameData();
  }

  void _initializeReels() {
    reels = List.generate(
      3,
      (_) => List.generate(
        12,
        (_) {
          // Daha yüksek değerli sembolleri daha sık görünecek şekilde ayarlayın
          if (random.nextInt(100) < 30) {
            // %30 olasılıkla özel sembol
            return symbols[0]; // Örneğin, ilk sembol özel sembol
          } else {
            return symbols[
                random.nextInt(symbols.length - 1) + 1]; // Diğer semboller
          }
        },
      ),
    );
  }

  void _setupAnimations() {
    spinControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(seconds: 2 + index),
        vsync: this,
      ),
    );

    spinAnimations = spinControllers.map((controller) {
      return Tween<double>(begin: 0, end: 12).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
    }).toList();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // AppBar transparan yapıldı
        elevation: 0, // Gölgeyi kaldırır
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/deep_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _buildHeader(),
                  _buildEnergyAndStats(),
                  Expanded(
                    child: _buildMainGame(constraints),
                  ),
                  _buildBottomControls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border(bottom: BorderSide(color: Colors.purpleAccent)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'COSMIC SLOTS',
            style: GoogleFonts.russoOne(
              fontSize: 24,
              color: Colors.white,
              shadows: [Shadow(color: Colors.purpleAccent, blurRadius: 10)],
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyAndStats() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEnergyBar(),
          SizedBox(height: 8),
          _buildStatsBar(),
        ],
      ),
    );
  }

  Widget _buildEnergyBar() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purpleAccent),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cosmic Energy',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                '${energyLevel.toInt()}%',
                style: TextStyle(color: Colors.amber, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 8),
          FAProgressBar(
            currentValue: energyLevel,
            maxValue: maxEnergy,
            size: 12,
            borderRadius: BorderRadius.circular(8),
            progressColor: Colors.purpleAccent,
            backgroundColor: Colors.purple[900]!,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(Icons.diamond, 'Crystals', crystals.toString()),
        _buildStatItem(Icons.bolt, 'Combo', 'x$comboCount'),
        _buildStatItem(Icons.stars, 'Best', maxCombo.toString()),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          SizedBox(width: 4),
          Column(
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                value,
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainGame(BoxConstraints constraints) {
    double availableHeight = constraints.maxHeight;
    double slotMachineHeight = availableHeight * 0.6;

    return Column(
      children: [
        Expanded(
          child: _buildSlotMachine(slotMachineHeight),
        ),
        SizedBox(
          height: 100,
          child: _buildPowerUps(),
        ),
      ],
    );
  }

  Widget _buildSlotMachine(double height) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWinLines(),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => Expanded(
                    child: _buildReel(index),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReel(int reelIndex) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent),
      ),
      child: AnimatedBuilder(
        animation: spinAnimations[reelIndex],
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (slotIndex) {
                final symbolIndex =
                    (spinAnimations[reelIndex].value.floor() + slotIndex) % 12;
                final symbol = reels[reelIndex][symbolIndex];
                return Expanded(child: _buildSymbol(symbol));
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSymbol(SlotSymbol symbol) {
    return Container(
      margin: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: symbol.isSpecial ? Colors.amber : Colors.purpleAccent,
          width: symbol.isSpecial ? 2 : 1,
        ),
        gradient: RadialGradient(
          colors: [
            symbol.color.withOpacity(0.3),
            Colors.black87,
          ],
        ),
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(
            symbol.icon,
            color: symbol.color,
          ),
        ),
      ),
    );
  }

  Widget _buildWinLines() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWinLine('Top', Icons.arrow_upward),
          _buildWinLine('Middle', Icons.remove),
          _buildWinLine('Bottom', Icons.arrow_downward),
          _buildWinLine('Diagonal', Icons.clear),
        ],
      ),
    );
  }

  Widget _buildWinLine(String label, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.amber, size: 16),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPowerUps() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: powerUps.length,
      itemBuilder: (context, index) => _buildPowerUpCard(powerUps[index]),
    );
  }

  Widget _buildPowerUpCard(PowerUp powerUp) {
    return GestureDetector(
      onTap: () => _activatePowerUp(powerUp),
      child: Container(
        width: 80,
        margin: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: powerUp.isActive ? Colors.purpleAccent : Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: powerUp.isActive ? Colors.amber : Colors.purpleAccent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              powerUp.icon,
              color: powerUp.isActive ? Colors.amber : Colors.white,
              size: 30,
            ),
            Text(
              powerUp.name,
              style: TextStyle(
                color: powerUp.isActive ? Colors.amber : Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '${powerUp.cost}',
              style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.purpleAccent)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBetControls(),
          SizedBox(height: 16),
          _buildSpinButton(),
        ],
      ),
    );
  }

  Widget _buildBetControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBetButton(Icons.remove, () => _changeBet(-10)),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BET',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                betAmount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _buildBetButton(Icons.add, () => _changeBet(10)),
      ],
    );
  }

  Widget _buildBetButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.purpleAccent),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSpinButton() {
    return GestureDetector(
      onTap: _spin,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSpinning
                ? [Colors.grey, Colors.grey.shade700]
                : [Colors.purple, Colors.deepPurple],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Text(
          isSpinning ? 'SPINNING...' : 'SPIN',
          style: GoogleFonts.russoOne(
            fontSize: 24,
            color: Colors.white,
            shadows: [Shadow(color: Colors.purple, blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  void _startEnergyTimer() {
    energyTimer?.cancel();
    energyTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!isSpinning && energyLevel < maxEnergy) {
        setState(() {
          energyLevel = min(maxEnergy, energyLevel + 2);
        });
      }
    });
  }

  void _changeBet(int amount) {
    if (!isSpinning) {
      setState(() {
        int newBet = betAmount + amount;
        if (newBet >= 20 && newBet <= crystals) {
          betAmount = newBet;
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _spin() {
    if (isSpinning || crystals < betAmount) {
      HapticFeedback.heavyImpact();
      if (crystals < betAmount) _showInsufficientFundsDialog();
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      isSpinning = true;
      crystals -= betAmount;
    });

    // Yeni semboller oluştur
    for (int i = 0; i < reels.length; i++) {
      reels[i] =
          List.generate(12, (_) => symbols[random.nextInt(symbols.length)]);
    }

    // Makaraları döndür
    for (int i = 0; i < spinControllers.length; i++) {
      spinControllers[i].forward(from: 0).then((_) {
        if (i == spinControllers.length - 1) {
          _checkWin();
        }
      });
    }
  }

  void _checkWin() {
    bool hasEnergyShield = powerUps[0].isActive;
    bool hasDoubleRewards = powerUps[1].isActive;
    bool hasComboBoost = powerUps[2].isActive;

    List<List<SlotSymbol>> grid = List.generate(
      3,
      (row) => List.generate(
        3,
        (col) => reels[col][spinAnimations[col].value.floor() % 12],
      ),
    );

    int totalWin = 0;
    bool hasWin = false;

    // Yatay kontrol
    for (int row = 0; row < 3; row++) {
      if (_checkLine(grid[row])) {
        totalWin += _calculateWin(grid[row], hasDoubleRewards);
        hasWin = true;
      }
    }

    // Çapraz kontrol
    List<SlotSymbol> diagonal1 = [grid[0][0], grid[1][1], grid[2][2]];
    List<SlotSymbol> diagonal2 = [grid[0][2], grid[1][1], grid[2][0]];

    if (_checkLine(diagonal1)) {
      totalWin += _calculateWin(diagonal1, hasDoubleRewards);
      hasWin = true;
    }
    if (_checkLine(diagonal2)) {
      totalWin += _calculateWin(diagonal2, hasDoubleRewards);
      hasWin = true;
    }

    setState(() {
      isSpinning = false;

      if (hasWin) {
        crystals += totalWin;
        comboCount++;
        if (hasComboBoost) comboCount++;
        if (comboCount > maxCombo) maxCombo = comboCount;
        energyLevel = min(maxEnergy, energyLevel + 15);
        _showWinDialog(totalWin);
      } else {
        if (!hasEnergyShield) {
          comboCount = 0;
          energyLevel = max(0, energyLevel - 10);
        }
      }
    });

    if (random.nextInt(100) < 10) {
      // %10 olasılıkla bonus
      setState(() {
        crystals += 50; // Rastgele 50 kristal bonus
      });
      _showBonusDialog(50);
    }

    _saveGameData();
  }

  bool _checkLine(List<SlotSymbol> line) {
    return line[0].name == line[1].name || line[1].name == line[2].name;
  }

  int _calculateWin(List<SlotSymbol> line, bool hasDoubleRewards) {
    int baseWin = line[0].value * betAmount ~/ 10;

    if (line[0].isSpecial) baseWin *= 2;
    if (hasDoubleRewards) baseWin *= 2;

    // Combo sayısına göre ekstra çarpan
    int comboMultiplier = comboCount > 5 ? comboCount * 2 : comboCount + 1;

    return baseWin * comboMultiplier;
  }

  void _showWinDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.amber, Colors.orange],
          ).createShader(bounds),
          child: Text(
            'Cosmic Win!',
            style: GoogleFonts.russoOne(fontSize: 28, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_motion, color: Colors.amber, size: 50),
            SizedBox(height: 16),
            Text(
              'You won $amount crystals!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (comboCount > 1)
              Text(
                'Combo x$comboCount!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Continue',
              style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 18),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (energyLevel >= maxEnergy) {
                _showEnergyFullDialog();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBonusDialog(int amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Bonus!',
          style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 50),
            SizedBox(height: 16),
            Text(
              'You won $amount extra crystals!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Awesome!',
              style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showEnergyFullDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Energy Overcharge!',
          style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Colors.amber, size: 60),
            SizedBox(height: 16),
            Text(
              'Your cosmic energy is at maximum!\nNext spin will have special rewards!',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Awesome!',
              style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _activatePowerUp(PowerUp powerUp) {
    if (crystals < powerUp.cost || powerUp.isActive) {
      if (crystals < powerUp.cost) _showInsufficientFundsDialog();
      return;
    }

    setState(() {
      crystals -= powerUp.cost;
      powerUp.isActive = true;
    });

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

  void _showInsufficientFundsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Insufficient Crystals',
          style: GoogleFonts.russoOne(color: Colors.white, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 50),
            SizedBox(height: 16),
            Text(
              'You don\'t have enough crystals!',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'OK',
              style: GoogleFonts.russoOne(color: Colors.white, fontSize: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showPowerUpActivatedDialog(PowerUp powerUp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Power-Up Activated!',
          style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(powerUp.icon, color: Colors.amber, size: 50),
            SizedBox(height: 16),
            Text(
              powerUp.name,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              powerUp.description,
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Duration: ${powerUp.duration.inMinutes} min',
              style: TextStyle(color: Colors.amber, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Got it!',
              style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.purple[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'How to Play',
          style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoSection(
                'Cosmic Energy',
                '• Energy increases over time\n• Win to gain more energy\n• Full energy grants special rewards',
              ),
              _buildInfoSection(
                'Power-Ups',
                '• Energy Shield: Prevents energy loss\n• Double Crystal: 2x rewards\n• Combo Boost: Extra combo multiplier',
              ),
              _buildInfoSection(
                'Winning Lines',
                '• Match 3 symbols horizontally\n• Match 3 symbols diagonally\n• Special symbols give 2x rewards',
              ),
              _buildInfoSection(
                'Combos',
                '• Win streaks increase multiplier\n• Keep winning to build combos\n• Higher combos = bigger rewards',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Got it!',
              style: GoogleFonts.russoOne(color: Colors.amber, fontSize: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGameData() async {
    final prefs = await SharedPreferences.getInstance();
    // await prefs.setInt('crystals', crystals);
    await prefs.setInt('maxCombo', maxCombo);
    await prefs.setInt('energy', energyLevel.toInt());
  }

  Future<void> _loadGameData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      //  crystals = prefs.getInt('crystals') ?? 1000;
      maxCombo = prefs.getInt('maxCombo') ?? 0;
      energyLevel = (prefs.getInt('energy') ?? 50).toDouble();
    });
  }

  @override
  void dispose() {
    // Timer'ları temizle
    energyTimer?.cancel();
    for (var powerUp in powerUps) {
      powerUp.activeTimer?.cancel();
    }

    // Animasyon kontrolcülerini temizle
    for (var controller in spinControllers) {
      controller.dispose();
    }
    energyController.dispose();

    super.dispose();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Ekran yönünü dikey olarak sabitle
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Sistem UI renklerini ayarla
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MaterialApp(
      title: 'Cosmic Slots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purple,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'RussoOne',
      ),
      home: const CosmicSlotGame(),
    ),
  );
}
