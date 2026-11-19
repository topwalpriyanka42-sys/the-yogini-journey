import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Level {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const Level(this.label);
  final String label;
}

class Course {
  const Course(
    this.title,
    this.level,
    this.minutes,
    this.image,
    this.description,
  );

  final String title;
  final Level level;
  final int minutes;
  final String image;
  final String description;
}

class BreathPractice {
  const BreathPractice(this.name, this.description);

  final String name;
  final String description;
}

final coursesProvider = Provider<List<Course>>(
  (ref) => const [
    Course(
      'Morning Yoga',
      Level.beginner,
      15,
      'morning',
      'A gentle introduction to moving with your breath.',
    ),
    Course(
      'Balance Training',
      Level.intermediate,
      25,
      'balance',
      'Practice steady transitions and standing balance.',
    ),
    Course(
      'Advanced Meditation',
      Level.advanced,
      30,
      'studio',
      'Explore longer periods of quiet, seated attention.',
    ),
    Course(
      'Introduction to Yoga',
      Level.beginner,
      20,
      'studio',
      'Get familiar with foundational poses and simple transitions.',
    ),
    Course(
      'Flexibility Yoga',
      Level.intermediate,
      25,
      'morning',
      'Explore comfortable ranges of motion with supported stretches.',
    ),
    Course(
      'Strength and Balance',
      Level.advanced,
      35,
      'balance',
      'Build control through standing sequences and slow transitions.',
    ),
  ],
);

final breathPracticesProvider = Provider<List<BreathPractice>>(
  (ref) => const [
    BreathPractice('Deep Breathing', 'Explore a gentle, comfortable breath.'),
    BreathPractice('Bhramari', 'Get to know the humming breath.'),
    BreathPractice(
      'Anulom Vilom',
      'Preview a traditional alternate-nostril practice.',
    ),
    BreathPractice('Nadi Shodhana', 'Learn about alternate-nostril breathing.'),
    BreathPractice(
      'Ujjayi',
      'Meet the steady breath used in some yoga traditions.',
    ),
    BreathPractice(
      'Kapalbhati',
      'An advanced practice that calls for qualified instruction.',
    ),
  ],
);
