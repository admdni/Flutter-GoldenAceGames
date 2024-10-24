import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solitaire Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.green[800],
      ),
      home: SolitaireGame(),
    );
  }
}

class PlayingCard {
  final String suit;
  final String value;
  final String image;
  bool faceUp;

  PlayingCard({
    required this.suit,
    required this.value,
    required this.image,
    this.faceUp = false,
  });

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      suit: json['suit'],
      value: json['value'],
      image: json['image'],
    );
  }

  int get numericValue {
    switch (value) {
      case 'ACE':
        return 1;
      case 'JACK':
        return 11;
      case 'QUEEN':
        return 12;
      case 'KING':
        return 13;
      default:
        return int.parse(value);
    }
  }

  String get color {
    return (suit == 'HEARTS' || suit == 'DIAMONDS') ? 'Red' : 'Black';
  }
}

class SolitaireGame extends StatefulWidget {
  @override
  _SolitaireGameState createState() => _SolitaireGameState();
}

class _SolitaireGameState extends State<SolitaireGame>
    with WidgetsBindingObserver {
  List<List<PlayingCard>> tableau = List.generate(7, (_) => []);
  List<PlayingCard> stock = [];
  List<PlayingCard> waste = [];
  List<PlayingCard?> foundation = List.filled(4, null);

  int moves = 0;
  int score = 0;
  int timeElapsed = 0;
  int highScore = 0;
  Timer? _timer;
  String? deckId;
  bool isGamePaused = false;
  List<Map<String, dynamic>> moveHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHighScore();
    _startNewGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseGame();
    } else if (state == AppLifecycleState.resumed) {
      _resumeGame();
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
    });
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!isGamePaused) {
        setState(() {
          timeElapsed++;
        });
      }
    });
  }

  Future<void> _startNewGame() async {
    _timer?.cancel();
    await _getNewDeck();
    await _dealCards();
    setState(() {
      moves = 0;
      score = 0;
      timeElapsed = 0;
      isGamePaused = false;
      moveHistory.clear();
    });
    _startTimer();
  }

  Future<void> _getNewDeck() async {
    final response = await http.get(Uri.parse(
        'https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      deckId = data['deck_id'];
    } else {
      throw Exception('Failed to load deck');
    }
  }

  Future<void> _dealCards() async {
    final response = await http.get(Uri.parse(
        'https://deckofcardsapi.com/api/deck/$deckId/draw/?count=52'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<PlayingCard> allCards = (data['cards'] as List)
          .map((card) => PlayingCard.fromJson(card))
          .toList();

      setState(() {
        tableau = List.generate(7, (_) => []);
        stock = allCards;
        waste = [];
        foundation = List.filled(4, null);
        for (int i = 0; i < 7; i++) {
          for (int j = 0; j <= i; j++) {
            PlayingCard card = stock.removeLast();
            card.faceUp = j == i;
            tableau[i].add(card);
          }
        }
      });
    } else {
      throw Exception('Failed to deal cards');
    }
  }

  void _drawCard() {
    if (stock.isNotEmpty) {
      setState(() {
        waste.add(stock.removeLast()..faceUp = true);
        moves++;
        _addToMoveHistory('draw');
      });
    } else if (waste.isNotEmpty) {
      setState(() {
        stock = waste.reversed.toList();
        for (var card in stock) {
          card.faceUp = false;
        }
        waste.clear();
        moves++;
        _addToMoveHistory('reset_waste');
      });
    }
  }

  bool _canMoveToFoundation(PlayingCard card, int foundationIndex) {
    if (foundation[foundationIndex] == null) {
      return card.value == 'ACE';
    } else {
      return card.suit == foundation[foundationIndex]!.suit &&
          card.numericValue == foundation[foundationIndex]!.numericValue + 1;
    }
  }

  bool _canMoveToTableau(PlayingCard card, int tableauIndex) {
    if (tableau[tableauIndex].isEmpty) {
      return card.value == 'KING';
    } else {
      PlayingCard topCard = tableau[tableauIndex].last;
      return card.color != topCard.color &&
          card.numericValue == topCard.numericValue - 1;
    }
  }

  void _moveCard(PlayingCard card, int? fromTableauIndex, int? toTableauIndex,
      int? foundationIndex) {
    setState(() {
      if (foundationIndex != null &&
          _canMoveToFoundation(card, foundationIndex)) {
        foundation[foundationIndex] = card;
        _removeCardFromSource(card, fromTableauIndex);
        score += 10;
        _addToMoveHistory(
            'to_foundation', card, fromTableauIndex, foundationIndex);
      } else if (toTableauIndex != null &&
          _canMoveToTableau(card, toTableauIndex)) {
        tableau[toTableauIndex].add(card);
        _removeCardFromSource(card, fromTableauIndex);
        score += 5;
        _addToMoveHistory('to_tableau', card, fromTableauIndex, toTableauIndex);
      }
      moves++;
    });
    _checkGameWon();
  }

  void _removeCardFromSource(PlayingCard card, int? tableauIndex) {
    if (tableauIndex != null) {
      tableau[tableauIndex].remove(card);
      if (tableau[tableauIndex].isNotEmpty) {
        tableau[tableauIndex].last.faceUp = true;
      }
    } else {
      waste.remove(card);
    }
  }

  void _checkGameWon() {
    if (foundation.every((pile) => pile != null && pile.value == 'KING')) {
      _timer?.cancel();
      if (score > highScore) {
        highScore = score;
        _saveHighScore();
      }
      _showGameOverDialog(true);
    }
  }

  void _showGameOverDialog(bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(won ? 'Congratulations!' : 'Game Over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? 'You won the game!' : 'Better luck next time!'),
              SizedBox(height: 10),
              Text('Score: $score'),
              Text('Time: ${_formatTime(timeElapsed)}'),
              Text('Moves: $moves'),
              if (score > highScore)
                Text('New High Score!',
                    style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              child: Text('New Game'),
              onPressed: () {
                Navigator.of(context).pop();
                _startNewGame();
              },
            ),
          ],
        );
      },
    );
  }

  void _pauseGame() {
    setState(() {
      isGamePaused = true;
    });
  }

  void _resumeGame() {
    setState(() {
      isGamePaused = false;
    });
  }

  void _addToMoveHistory(String moveType,
      [PlayingCard? card, int? from, int? to]) {
    moveHistory.add({
      'type': moveType,
      'card': card != null ? '${card.value} of ${card.suit}' : null,
      'from': from,
      'to': to,
    });
  }

  void _undoMove() {
    if (moveHistory.isEmpty) return;

    final lastMove = moveHistory.removeLast();
    setState(() {
      switch (lastMove['type']) {
        case 'draw':
          if (waste.isNotEmpty) {
            stock.add(waste.removeLast()..faceUp = false);
          }
          break;
        case 'reset_waste':
          waste = stock.reversed.toList();
          for (var card in waste) {
            card.faceUp = true;
          }
          stock.clear();
          break;
        case 'to_foundation':
          final card = foundation[lastMove['to']]!;
          foundation[lastMove['to']] = null;
          if (lastMove['from'] != null) {
            tableau[lastMove['from']].add(card);
          } else {
            waste.add(card);
          }
          score -= 10;
          break;
        case 'to_tableau':
          final card = tableau[lastMove['to']].removeLast();
          if (lastMove['from'] != null) {
            tableau[lastMove['from']].add(card);
          } else {
            waste.add(card);
          }
          score -= 5;
          break;
      }
      moves--;
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Solitaire Game'),
        actions: [
          IconButton(
            icon: Icon(isGamePaused ? Icons.play_arrow : Icons.pause),
            onPressed: isGamePaused ? _resumeGame : _pauseGame,
            tooltip: isGamePaused ? 'Resume Game' : 'Pause Game',
          ),
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: _undoMove,
            tooltip: 'Undo Move',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _startNewGame,
            tooltip: 'New Game',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/black_jack.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: isGamePaused
              ? Center(
                  child: Text('Game Paused',
                      style: TextStyle(fontSize: 24, color: Colors.white)))
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _buildGameArea(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Time: ${_formatTime(timeElapsed)}',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          Text(
            'Moves: $moves',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          Text(
            'Score: $score',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
          Text(
            'High Score: $highScore',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      children: [
        _buildStockAndWaste(),
        SizedBox(height: 16),
        _buildFoundation(),
        SizedBox(height: 16),
        Expanded(child: _buildTableau()),
      ],
    );
  }

  Widget _buildStockAndWaste() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _drawCard,
          child: _buildCardPlaceholder(
            child: stock.isNotEmpty
                ? Image.network(
                    'https://deckofcardsapi.com/static/img/back.png')
                : Icon(Icons.refresh, color: Colors.white, size: 32),
          ),
        ),
        SizedBox(width: 16),
        waste.isNotEmpty
            ? Draggable<PlayingCard>(
                data: waste.last,
                child: _buildCardImage(waste.last),
                feedback: _buildCardImage(waste.last),
                childWhenDragging: _buildCardPlaceholder(),
              )
            : _buildCardPlaceholder(),
      ],
    );
  }

  Widget _buildFoundation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (index) {
        return DragTarget<PlayingCard>(
          builder: (context, candidateData, rejectedData) {
            return _buildCardPlaceholder(
              child: foundation[index] != null
                  ? _buildCardImage(foundation[index]!)
                  : Icon(Icons.add_circle,
                      color: Colors.white.withOpacity(0.5), size: 32),
            );
          },
          onWillAccept: (card) => _canMoveToFoundation(card!, index),
          onAccept: (card) => _moveCard(card, null, null, index),
        );
      }),
    );
  }

  Widget _buildTableau() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(7, (index) {
        return Expanded(
          child: DragTarget<PlayingCard>(
            builder: (context, candidateData, rejectedData) {
              return Stack(
                children: [
                  ...tableau[index].asMap().entries.map((entry) {
                    int i = entry.key;
                    PlayingCard card = entry.value;
                    return Positioned(
                      top: i * 30.0,
                      child: _buildTableauCard(card, index, i),
                    );
                  }).toList(),
                  if (tableau[index].isEmpty) _buildCardPlaceholder(),
                ],
              );
            },
            onWillAccept: (card) => _canMoveToTableau(card!, index),
            onAccept: (card) => _moveCard(card, null, index, null),
          ),
        );
      }),
    );
  }

  Widget _buildTableauCard(PlayingCard card, int tableauIndex, int cardIndex) {
    return card.faceUp
        ? Draggable<PlayingCard>(
            data: card,
            child: _buildCardImage(card),
            feedback: _buildCardImage(card),
            childWhenDragging: SizedBox(height: 80, width: 60),
            onDragStarted: () {
              setState(() {
                tableau[tableauIndex]
                    .removeRange(cardIndex, tableau[tableauIndex].length);
              });
            },
            onDraggableCanceled: (_, __) {
              setState(() {
                tableau[tableauIndex]
                    .addAll(tableau[tableauIndex].sublist(cardIndex));
              });
            },
          )
        : _buildCardImage(card);
  }

  Widget _buildCardImage(PlayingCard card) {
    return Container(
      height: 80,
      width: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: card.faceUp
            ? Image.network(card.image, fit: BoxFit.cover)
            : Image.network('https://deckofcardsapi.com/static/img/back.png',
                fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildCardPlaceholder({Widget? child}) {
    return Container(
      height: 80,
      width: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: child,
    );
  }
}
