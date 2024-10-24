// main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';

import 'homePage.dart';

void main() {
  runApp(const TriviaApp());
}

class TriviaApp extends StatelessWidget {
  const TriviaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galactic Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF0B0B2D),
        fontFamily: GoogleFonts.orbitron().fontFamily,
      ),
      home: const TriviaGame(),
    );
  }
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class Question {
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;
  List<String> allAnswers;

  Question({
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
  }) : allAnswers = [] {
    allAnswers = [...incorrectAnswers, correctAnswer];
    allAnswers.shuffle();
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      question: HtmlUnescape().convert(json['question']),
      correctAnswer: HtmlUnescape().convert(json['correct_answer']),
      incorrectAnswers: (json['incorrect_answers'] as List)
          .map((e) => HtmlUnescape().convert(e.toString()))
          .toList(),
    );
  }
}

class StarFieldPainter extends CustomPainter {
  final double rotation;
  final List<Offset> stars = List.generate(
      150,
      (index) => Offset(
            Random().nextDouble() * 1000,
            Random().nextDouble() * 2000,
          ));
  final List<double> starSizes =
      List.generate(150, (index) => Random().nextDouble() * 2 + 1);

  StarFieldPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (int i = 0; i < stars.length; i++) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, starSizes[i]);

      canvas.drawCircle(stars[i], starSizes[i] * 2, glowPaint);
      canvas.drawCircle(stars[i], starSizes[i], paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(StarFieldPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

class TriviaGame extends StatefulWidget {
  const TriviaGame({Key? key}) : super(key: key);

  @override
  _TriviaGameState createState() => _TriviaGameState();
}

class _TriviaGameState extends State<TriviaGame> with TickerProviderStateMixin {
  final List<Category> categories = [
    Category(
      id: '9',
      name: 'General Knowledge',
      icon: Icons.lightbulb,
      color: Colors.amber,
    ),
    Category(
      id: '17',
      name: 'Science & Nature',
      icon: Icons.science,
      color: Colors.green,
    ),
    Category(
      id: '18',
      name: 'Computers',
      icon: Icons.computer,
      color: Colors.blue,
    ),
    Category(
      id: '23',
      name: 'History',
      icon: Icons.history,
      color: Colors.brown,
    ),
    Category(
      id: '21',
      name: 'Sports',
      icon: Icons.sports,
      color: Colors.orange,
    ),
  ];

  final Map<String, String> difficulties = {
    'easy': 'Cadet',
    'medium': 'Captain',
    'hard': 'Commander'
  };

  List<Question>? questions;
  int currentQuestionIndex = 0;
  int score = 0;
  bool isLoading = false;
  Timer? timer;
  int timeLeft = 30;
  String? selectedCategory;
  String? selectedDifficulty;
  bool showCategorySelection = true;
  int jokers = 3;
  late AnimationController _starController;
  late Animation<double> _starAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _starAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_starController);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadQuestions() async {
    if (selectedCategory == null || selectedDifficulty == null) return;

    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          'https://opentdb.com/api.php?amount=10&category=$selectedCategory&difficulty=$selectedDifficulty&type=multiple'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['response_code'] == 0) {
          setState(() {
            questions = (data['results'] as List)
                .map((q) => Question.fromJson(q))
                .toList();
            isLoading = false;
            showCategorySelection = false;
          });
          _startTimer();
        } else {
          throw Exception('Failed to load questions');
        }
      }
    } catch (e) {
      _showError('Failed to load questions. Please try again.');
      setState(() {
        isLoading = false;
        selectedCategory = null;
        selectedDifficulty = null;
      });
    }
  }

  void _startTimer() {
    timer?.cancel();
    timeLeft = 30;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          timer.cancel();
          _showTimeUpDialog();
        }
      });
    });
  }

  void _handleAnswer(String answer) {
    timer?.cancel();
    final currentQuestion = questions![currentQuestionIndex];

    if (answer == currentQuestion.correctAnswer) {
      setState(() {
        int basePoints = selectedDifficulty == 'easy'
            ? 10
            : selectedDifficulty == 'medium'
                ? 20
                : 30;
        int timeBonus = (timeLeft * 0.5).round();
        score += basePoints + timeBonus;
      });
      _showSuccessDialog(score);
    } else {
      _showWrongAnswerDialog(currentQuestion.correctAnswer);
    }
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions!.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _startTimer();
      });
    } else {
      _showGameOverDialog();
    }
  }

  void _useJoker() {
    if (jokers > 0) {
      timer?.cancel();
      setState(() {
        jokers--;
      });
      _showJokerUsedDialog();
    }
  }

  Widget _buildCategorySelection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0B0B2D),
            Color(0xFF1A1A4D),
          ],
        ),
      ),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _starAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: StarFieldPainter(_starAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Text(
                        'GALACTIC QUIZ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.purple,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Select Your Mission',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 30),
                    ...categories
                        .map((category) => Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: AnimatedScale(
                                scale: selectedCategory == category.id
                                    ? 1.05
                                    : 1.0,
                                duration: Duration(milliseconds: 200),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: selectedCategory == category.id
                                        ? [
                                            BoxShadow(
                                              color: category.color
                                                  .withOpacity(0.5),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          selectedCategory == category.id
                                              ? category.color
                                              : Colors.black45,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        side: BorderSide(
                                          color: category.color,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedCategory = category.id;
                                        if (selectedDifficulty != null) {
                                          _loadQuestions();
                                        }
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          category.icon,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        SizedBox(width: 15),
                                        Expanded(
                                          child: Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          selectedCategory == category.id
                                              ? Icons.check_circle
                                              : Icons.arrow_forward_ios,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                    SizedBox(height: 10),
                    Text(
                      'Select Difficulty',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: difficulties.entries.map((difficulty) {
                        final isSelected = selectedDifficulty == difficulty.key;
                        final color = difficulty.key == 'easy'
                            ? Colors.green
                            : difficulty.key == 'medium'
                                ? Colors.orange
                                : Colors.red;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDifficulty = difficulty.key;
                              if (selectedCategory != null) {
                                _loadQuestions();
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.2)
                                  : Colors.black45,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.grey.withOpacity(0.5),
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  difficulty.key == 'easy'
                                      ? Icons.sentiment_satisfied
                                      : difficulty.key == 'medium'
                                          ? Icons.sentiment_neutral
                                          : Icons.sentiment_very_dissatisfied,
                                  color: isSelected ? color : Colors.grey,
                                  size: 30,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  difficulty.value,
                                  style: TextStyle(
                                    color: isSelected ? color : Colors.grey,
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionScreen() {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _starAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: StarFieldPainter(_starAnimation.value),
              size: Size.infinite,
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(),
                SizedBox(height: 20),
                _buildQuestionCard(),
                SizedBox(height: 20),
                _buildAnswers(),
                _buildJokerButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.stars, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Score: $score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Jokers: $jokers',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  timeLeft > 10 ? Colors.green : Colors.red,
                  timeLeft > 10 ? Colors.green[700]! : Colors.red[700]!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (timeLeft > 10 ? Colors.green : Colors.red)
                      .withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$timeLeft',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple[900]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz, color: Colors.purple[300], size: 24),
              SizedBox(width: 10),
              Text(
                'Question ${currentQuestionIndex + 1}/${questions!.length}',
                style: TextStyle(
                  color: Colors.purple[300],
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            questions![currentQuestionIndex].question,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswers() {
    return Expanded(
      child: ListView.builder(
        itemCount: questions![currentQuestionIndex].allAnswers.length,
        itemBuilder: (context, index) {
          final answer = questions![currentQuestionIndex].allAnswers[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[900]!.withOpacity(0.5),
                  padding: EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.purple[300]!, width: 1),
                  ),
                ),
                onPressed: () => _handleAnswer(answer),
                child: Row(
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purple[300]!.withOpacity(0.3),
                        border: Border.all(color: Colors.purple[300]!),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + index),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        answer,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJokerButton() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: jokers > 0 ? Colors.orange : Colors.grey,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: jokers > 0 ? _useJoker : null,
        icon: Icon(Icons.auto_awesome),
        label: Text('Skip Question ($jokers left)'),
      ),
    );
  }

  void _showSuccessDialog(int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green),
        ),
        title: Text(
          'Correct!',
          style: TextStyle(color: Colors.green),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
            SizedBox(height: 15),
            Text(
              '+$points Points!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Total Score: $score',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextQuestion();
            },
            child: Text(
              'Next Question',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showWrongAnswerDialog(String correctAnswer) {
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
          'Wrong Answer!',
          style: TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, color: Colors.red, size: 50),
            SizedBox(height: 15),
            Text(
              'The correct answer was:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 10),
            Text(
              correctAnswer,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextQuestion();
            },
            child: Text(
              'Next Question',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.orange),
        ),
        title: Text(
          'Time\'s Up!',
          style: TextStyle(color: Colors.orange),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, color: Colors.orange, size: 50),
            SizedBox(height: 15),
            Text(
              'The correct answer was:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 10),
            Text(
              questions![currentQuestionIndex].correctAnswer,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextQuestion();
            },
            child: Text(
              'Next Question',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purple),
        ),
        title: Text(
          'Mission Complete!',
          style: TextStyle(
            color: Colors.purple[300],
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, color: Colors.amber, size: 50),
            SizedBox(height: 20),
            Text(
              'Final Score',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            Text(
              '$score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Difficulty: ${difficulties[selectedDifficulty]}',
              style: TextStyle(color: Colors.white70),
            ),
            Text(
              'Jokers Left: $jokers',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                showCategorySelection = true;
                currentQuestionIndex = 0;
                score = 0;
                jokers = 3;
              });
            },
            child: Text(
              'Play Again',
              style: TextStyle(color: Colors.purple[300]),
            ),
          ),
        ],
      ),
    );
  }

  void _showJokerUsedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.orange),
        ),
        title: Text(
          'Joker Used',
          style: TextStyle(color: Colors.orange),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange, size: 50),
            SizedBox(height: 15),
            Text(
              'Question skipped!\nJokers remaining: $jokers',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nextQuestion();
            },
            child: Text(
              'Continue',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red),
        ),
        title: Text(
          'Error',
          style: TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 15),
            Text(
              message,
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isLoading = false;
              });
            },
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
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
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          color: Colors.purple[300],
                          strokeWidth: 8,
                        ),
                      ),
                      Icon(
                        Icons.rocket_launch,
                        color: Colors.purple[300],
                        size: 40,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Preparing Mission...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            )
          : AnimatedSwitcher(
              duration: Duration(milliseconds: 500),
              child: showCategorySelection
                  ? _buildCategorySelection()
                  : _buildQuestionScreen(),
            ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
