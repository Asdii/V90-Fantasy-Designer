import 'package:flutter/material.dart';

/// A lapidary handpiece meeting a small gemstone. Shared by the app header
/// and the generated launcher assets; deliberately vector-native at any size.
class MicroFantasyMark extends StatelessWidget {
  const MicroFantasyMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Micromotor con gema',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: MicroFantasyMarkPainter(
            ink: colors.primary,
            gem: colors.secondary,
            background: colors.primaryContainer,
          ),
        ),
      ),
    );
  }
}

class MicroFantasyMarkPainter extends CustomPainter {
  const MicroFantasyMarkPainter({
    this.ink = const Color(0xff1c567a),
    this.gem = const Color(0xff3aa1bb),
    this.background = const Color(0xffe6f2f6),
  });
  final Color ink;
  final Color gem;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(24),
      ),
      Paint()..color = background,
    );
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Short flexible lead and the stepped cylindrical handpiece.
    canvas.drawPath(
      Path()
        ..moveTo(21, 64)
        ..cubicTo(10, 65, 13, 81, 23, 84),
      line,
    );
    canvas.save();
    canvas.translate(44, 49);
    canvas.rotate(-.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, -11, 40, 22),
        const Radius.circular(7),
      ),
      Paint()..color = ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, -8)
        ..lineTo(25, -4)
        ..lineTo(25, 4)
        ..lineTo(13, 8)
        ..close(),
      Paint()..color = ink,
    );
    canvas.drawLine(const Offset(25, 0), const Offset(35, 0), line);
    for (var x = -6.0; x <= 6; x += 5) {
      canvas.drawLine(
        Offset(x, -7),
        Offset(x, 7),
        Paint()
          ..color = background
          ..strokeWidth = 1.7,
      );
    }
    canvas.drawLine(
      const Offset(-20, -6),
      const Offset(-12, -6),
      Paint()
        ..color = background
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    // Asymmetric silhouette stays readable as a gem beside a tool, not a drill.
    final stone = Path()
      ..moveTo(57, 63)
      ..lineTo(66, 53)
      ..lineTo(79, 53)
      ..lineTo(87, 64)
      ..lineTo(72, 83)
      ..close();
    canvas.drawPath(stone, Paint()..color = gem);
    final facets = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(57, 63)
        ..lineTo(87, 64)
        ..moveTo(66, 53)
        ..lineTo(64, 63)
        ..lineTo(72, 83)
        ..lineTo(79, 64)
        ..lineTo(79, 53),
      facets,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MicroFantasyMarkPainter oldDelegate) =>
      ink != oldDelegate.ink ||
      gem != oldDelegate.gem ||
      background != oldDelegate.background;
}
