import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const NBABreakerApp());
}

class NBABreakerApp extends StatelessWidget {
  const NBABreakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBA Breaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFA8320)),
        useMaterial3: true,
        fontFamily: 'Roboto', // Default, but implies standard look
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(),
      },
    );
  }
}

// --- Game Constants ---
const double kBallRadius = 10.0;
const double kPaddleHeight = 20.0;
const double kPaddleWidth = 100.0;
const double kBrickHeight = 30.0;
const double kBrickPadding = 4.0;

// --- NBA Colors ---
const Color kNBABallColor = Color(0xFFFA8320);
const Color kCourtColor = Color(0xFFD2A56D); // Wood floor
const Color kCourtLinesColor = Colors.white;
const Color kPaddleColor = Color(0xFF1D428A); // Generic NBA Blue

// Team Colors for Bricks
const List<Color> kTeamColors = [
  Color(0xFFCE1141), // Bulls Red
  Color(0xFF007A33), // Celtics Green
  Color(0xFF552583), // Lakers Purple
  Color(0xFFFDB927), // Lakers Gold
  Color(0xFF006BB6), // 76ers/Warriors Blue
  Color(0xFF98002E), // Heat Red
  Color(0xFF000000), // Nets Black
];

enum GameStatus { menu, playing, gameOver, won }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Game State
  GameStatus _status = GameStatus.menu;
  int _score = 0;
  int _lives = 3;
  
  // Physics State
  Size _screenSize = Size.zero;
  Offset _ballPos = Offset.zero;
  Offset _ballVel = Offset.zero;
  double _paddleX = 0.0;
  List<Brick> _bricks = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1), // Infinite loop basically
    )..addListener(_updateGame);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _status = GameStatus.playing;
      _score = 0;
      _lives = 3;
      _resetLevel();
    });
    _controller.repeat();
  }

  void _resetLevel() {
    // Center paddle
    _paddleX = (_screenSize.width - kPaddleWidth) / 2;
    
    // Reset ball
    _resetBall();
    
    // Generate Bricks
    _bricks.clear();
    int cols = 6;
    int rows = 5;
    double totalBrickWidth = _screenSize.width - (cols + 1) * kBrickPadding;
    double brickWidth = totalBrickWidth / cols;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _bricks.add(Brick(
          rect: Rect.fromLTWH(
            kBrickPadding + c * (brickWidth + kBrickPadding),
            kBrickPadding + 50 + r * (kBrickHeight + kBrickPadding), // 50 top margin
            brickWidth,
            kBrickHeight,
          ),
          color: kTeamColors[(r + c) % kTeamColors.length],
          points: (rows - r) * 10,
        ));
      }
    }
  }

  void _resetBall() {
    _ballPos = Offset(_screenSize.width / 2, _screenSize.height / 2);
    // Randomize start angle slightly
    double angle = (Random().nextBool() ? -1 : 1) * (pi / 4 + Random().nextDouble() * pi / 4);
    // Ensure it goes up initially? No, let's make it go down or random. 
    // Standard Arkanoid often starts attached to paddle, but let's just launch it.
    double speed = 5.0;
    _ballVel = Offset(cos(angle) * speed, -speed.abs()); // Launch upwards
  }

  void _updateGame() {
    if (_status != GameStatus.playing) return;

    setState(() {
      // 1. Move Ball
      _ballPos += _ballVel;

      // 2. Wall Collisions
      // Left
      if (_ballPos.dx - kBallRadius < 0) {
        _ballPos = Offset(kBallRadius, _ballPos.dy);
        _ballVel = Offset(-_ballVel.dx, _ballVel.dy);
      }
      // Right
      if (_ballPos.dx + kBallRadius > _screenSize.width) {
        _ballPos = Offset(_screenSize.width - kBallRadius, _ballPos.dy);
        _ballVel = Offset(-_ballVel.dx, _ballVel.dy);
      }
      // Top
      if (_ballPos.dy - kBallRadius < 0) {
        _ballPos = Offset(_ballPos.dx, kBallRadius);
        _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
      }
      // Bottom (Death)
      if (_ballPos.dy + kBallRadius > _screenSize.height) {
        _lives--;
        if (_lives <= 0) {
          _status = GameStatus.gameOver;
          _controller.stop();
        } else {
          _resetBall();
        }
        return;
      }

      // 3. Paddle Collision
      Rect paddleRect = Rect.fromLTWH(
        _paddleX, 
        _screenSize.height - kPaddleHeight - 20, // 20 padding from bottom
        kPaddleWidth, 
        kPaddleHeight
      );
      
      // Simple circle-rect collision check
      if (_ballPos.dy + kBallRadius >= paddleRect.top &&
          _ballPos.dy - kBallRadius <= paddleRect.bottom &&
          _ballPos.dx >= paddleRect.left &&
          _ballPos.dx <= paddleRect.right) {
        
        // Only bounce if moving down
        if (_ballVel.dy > 0) {
          // Calculate hit position relative to center of paddle (-1 to 1)
          double hitPoint = (_ballPos.dx - paddleRect.center.dx) / (kPaddleWidth / 2);
          
          // Deflect ball based on hit point
          double speed = _ballVel.distance;
          // Increase speed slightly on every paddle hit to make it harder
          speed = min(speed * 1.05, 12.0); 

          double maxBounceAngle = pi / 3; // 60 degrees
          double bounceAngle = hitPoint * maxBounceAngle;

          _ballVel = Offset(speed * sin(bounceAngle), -speed * cos(bounceAngle));
          
          // Ensure it's above the paddle to prevent sticking
          _ballPos = Offset(_ballPos.dx, paddleRect.top - kBallRadius - 1);
        }
      }

      // 4. Brick Collision
      for (int i = _bricks.length - 1; i >= 0; i--) {
        Brick brick = _bricks[i];
        if (brick.rect.contains(_ballPos)) {
          // Determine bounce direction (simplified)
          // Check previous position to see if we hit side or top/bottom
          Offset prevPos = _ballPos - _ballVel;
          
          bool hitHorizontal = prevPos.dx < brick.rect.left || prevPos.dx > brick.rect.right;
          bool hitVertical = prevPos.dy < brick.rect.top || prevPos.dy > brick.rect.bottom;

          if (hitVertical) {
            _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
          } else if (hitHorizontal) {
            _ballVel = Offset(-_ballVel.dx, _ballVel.dy);
          } else {
            // Fallback if inside
            _ballVel = Offset(_ballVel.dx, -_ballVel.dy);
          }

          _score += brick.points;
          _bricks.removeAt(i);
          break; // Only hit one brick per frame
        }
      }

      if (_bricks.isEmpty) {
        _status = GameStatus.won;
        _controller.stop();
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_status != GameStatus.playing) return;
    setState(() {
      _paddleX += details.delta.dx;
      // Clamp paddle to screen
      _paddleX = _paddleX.clamp(0.0, _screenSize.width - kPaddleWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for the first time
    if (_screenSize == Size.zero) {
      _screenSize = MediaQuery.of(context).size;
      // Initialize paddle center if not started
      if (_status == GameStatus.menu) {
        _paddleX = (_screenSize.width - kPaddleWidth) / 2;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanUpdate: _onPanUpdate,
        child: Stack(
          children: [
            // Game Rendering Layer
            CustomPaint(
              size: Size.infinite,
              painter: GamePainter(
                ballPos: _ballPos,
                paddleX: _paddleX,
                bricks: _bricks,
                screenSize: _screenSize,
              ),
            ),
            
            // UI Overlay (Score, Lives)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildScoreBoard('SCORE', '$_score'),
                  _buildScoreBoard('LIVES', '$_lives'),
                ],
              ),
            ),

            // Menus
            if (_status == GameStatus.menu)
              _buildMenu('NBA JAM BREAKER', 'TAP TO START', _startGame),
            
            if (_status == GameStatus.gameOver)
              _buildMenu('GAME OVER', 'TAP TO RESTART', _startGame),
              
            if (_status == GameStatus.won)
              _buildMenu('CHAMPION!', 'PLAY AGAIN', _startGame),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier', // Monospace for numbers
          ),
        ),
      ],
    );
  }

  Widget _buildMenu(String title, String buttonText, VoidCallback onPressed) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: kNBABallColor,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                shadows: [
                  Shadow(blurRadius: 10, color: Colors.orange, offset: Offset(0, 0)),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPaddleColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}

class Brick {
  final Rect rect;
  final Color color;
  final int points;

  Brick({required this.rect, required this.color, required this.points});
}

class GamePainter extends CustomPainter {
  final Offset ballPos;
  final double paddleX;
  final List<Brick> bricks;
  final Size screenSize;

  GamePainter({
    required this.ballPos,
    required this.paddleX,
    required this.bricks,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Court Background
    final Paint courtPaint = Paint()..color = kCourtColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), courtPaint);

    // Draw Court Lines (Simplified)
    final Paint linePaint = Paint()
      ..color = kCourtLinesColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Center Circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 50, linePaint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), linePaint);
    
    // Key Area (Top)
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 60, 0, 120, 150), linePaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, 150), radius: 60),
      0, pi, false, linePaint
    );

    // Key Area (Bottom - near paddle)
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 60, size.height - 150, 120, 150), linePaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width / 2, size.height - 150), radius: 60),
      pi, pi, false, linePaint
    );

    // 2. Draw Bricks
    for (var brick in bricks) {
      final Paint brickPaint = Paint()..color = brick.color;
      // Draw brick with slight bevel/shadow effect
      canvas.drawRect(brick.rect, brickPaint);
      
      // Highlight
      final Paint highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(brick.rect.deflate(2), highlightPaint);
    }

    // 3. Draw Paddle
    final Rect paddleRect = Rect.fromLTWH(
      paddleX, 
      size.height - kPaddleHeight - 20, 
      kPaddleWidth, 
      kPaddleHeight
    );
    final Paint paddlePaint = Paint()..color = kPaddleColor;
    // Rounded paddle
    canvas.drawRRect(RRect.fromRectAndRadius(paddleRect, const Radius.circular(10)), paddlePaint);
    
    // Paddle detail (stripes)
    final Paint stripePaint = Paint()..color = Colors.white.withOpacity(0.3);
    canvas.drawRect(
      Rect.fromLTWH(paddleRect.left + 10, paddleRect.top + 5, paddleRect.width - 20, 2), 
      stripePaint
    );
    canvas.drawRect(
      Rect.fromLTWH(paddleRect.left + 10, paddleRect.bottom - 7, paddleRect.width - 20, 2), 
      stripePaint
    );

    // 4. Draw Ball (Basketball)
    final Paint ballPaint = Paint()..color = kNBABallColor;
    canvas.drawCircle(ballPos, kBallRadius, ballPaint);
    
    // Ball Lines (Black lines on basketball)
    final Paint ballLinePaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawCircle(ballPos, kBallRadius, ballLinePaint); // Outline
    canvas.drawLine(
      ballPos + const Offset(-kBallRadius, 0), 
      ballPos + const Offset(kBallRadius, 0), 
      ballLinePaint
    ); // Horizontal
    
    // Curved lines on ball (simplified)
    Path ballPath = Path();
    ballPath.moveTo(ballPos.dx, ballPos.dy - kBallRadius);
    ballPath.quadraticBezierTo(
      ballPos.dx + kBallRadius * 0.5, ballPos.dy, 
      ballPos.dx, ballPos.dy + kBallRadius
    );
    canvas.drawPath(ballPath, ballLinePaint);
    
    ballPath.reset();
    ballPath.moveTo(ballPos.dx, ballPos.dy - kBallRadius);
    ballPath.quadraticBezierTo(
      ballPos.dx - kBallRadius * 0.5, ballPos.dy, 
      ballPos.dx, ballPos.dy + kBallRadius
    );
    canvas.drawPath(ballPath, ballLinePaint);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.ballPos != ballPos || 
           oldDelegate.paddleX != paddleX ||
           oldDelegate.bricks.length != bricks.length;
  }
}
