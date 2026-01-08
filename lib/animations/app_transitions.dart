import 'package:flutter/material.dart';

class AppTransitions {
  // 🎯 انتقالات الصفحات الرئيسية
  static Widget slideTransition(Widget child, Animation<double> animation) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }

  // 🌊 انتقال سلس من الأسفل
  static Widget slideUpTransition(Widget child, Animation<double> animation) {
    const begin = Offset(0.0, 1.0);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }

  // 🎭 انتقال التلاشي (Fade)
  static Widget fadeTransition(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  // 📱 انتقال مخصص للتطبيق
  static Widget customPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const curve = Curves.easeInOutCubic;
    
    var slideAnimation = Tween(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: curve));

    var fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: curve));

    return SlideTransition(
      position: animation.drive(slideAnimation),
      child: FadeTransition(
        opacity: animation.drive(fadeAnimation),
        child: child,
      ),
    );
  }

  // 🎨 انتقال الحجم (Scale)
  static Widget scaleTransition(Widget child, Animation<double> animation) {
    return ScaleTransition(
      scale: animation,
      child: child,
    );
  }

  // 🔄 انتقال الدوران (Rotation)
  static Widget rotationTransition(Widget child, Animation<double> animation) {
    return RotationTransition(
      turns: animation,
      child: child,
    );
  }

  // 📊 انتقالات الأزرار والبطاقات
  static Widget buttonPressAnimation({
    required Widget child,
    required VoidCallback onPressed,
    Duration duration = const Duration(milliseconds: 150),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.0),
      duration: duration,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          // Animation will be handled by the TweenAnimationBuilder
        },
        onTapUp: (_) {
          onPressed();
        },
        onTapCancel: () {
          // Reset animation
        },
        child: child,
      ),
    );
  }

  // 🎯 أنيميشن الظهور التدريجي للعناصر
  static Widget staggeredAnimation({
    required Widget child,
    required int index,
    Duration baseDelay = const Duration(milliseconds: 100),
    Duration duration = const Duration(milliseconds: 600),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // 🌟 أنيميشن الاهتزاز (Shake)
  static Widget shakeAnimation({
    required Widget child,
    bool trigger = false,
  }) {
    if (!trigger) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            10 * (1 - value) * (value < 0.5 ? 1 : -1),
            0,
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  // 💫 أنيميوان النبض (Pulse)
  static Widget pulseAnimation({
    required Widget child,
    bool trigger = false,
  }) {
    if (!trigger) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: 1.1),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // 🎭 أنيميوان التحميل (Loading)
  static Widget loadingAnimation({
    required Widget child,
    bool isLoading = false,
  }) {
    if (!isLoading) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 6.28, // Full rotation
          child: child,
        );
      },
      child: child,
    );
  }

  // 📱 مساعد للتنقل بين الصفحات
  static Route<T> slideRoute<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return customPageTransition(context, animation, secondaryAnimation, child);
      },
    );
  }

  static Route<T> fadeRoute<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return fadeTransition(child, animation);
      },
    );
  }

  static Route<T> scaleRoute<T>({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return scaleTransition(child, animation);
      },
    );
  }
}

// 🎨 كلاس مساعد للأنيميشن المتقدم
class AdvancedAnimations {
  // 🌊 أنيميوان الموجة (Wave)
  static Widget waveAnimation({
    required Widget child,
    bool trigger = false,
  }) {
    if (!trigger) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Transform.scale(
          scaleX: 1.0 + (0.1 * value),
          scaleY: 1.0 - (0.1 * value),
          child: child,
        );
      },
      child: child,
    );
  }

  // 🎯 أنيميوان الارتداد (Bounce)
  static Widget bounceAnimation({
    required Widget child,
    bool trigger = false,
  }) {
    if (!trigger) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * value * (1 - value) * 4),
          child: child,
        );
      },
      child: child,
    );
  }

  // 🌟 أنيميوان اللمعان (Shimmer)
  static Widget shimmerAnimation({
    required Widget child,
    bool trigger = false,
  }) {
    if (!trigger) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -1.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.3),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + value, 0),
              end: Alignment(1.0 + value, 0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }
}

// 🎯 ثوابت الأنيميوان
class AnimationConstants {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 800);

  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve bounceIn = Curves.bounceIn;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve elasticOut = Curves.elasticOut;
}
