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
    this.id,
    this.title,
    this.level,
    this.minutes,
    this.image,
    this.description,
  );

  final String id;
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
      'morning-yoga',
      'Morning Yoga',
      Level.beginner,
      15,
      'morning',
      'A gentle introduction to moving with your breath.',
    ),
    Course(
      'balance-training',
      'Balance Training',
      Level.intermediate,
      25,
      'balance',
      'Practice steady transitions and standing balance.',
    ),
    Course(
      'advanced-meditation',
      'Advanced Meditation',
      Level.advanced,
      30,
      'studio',
      'Explore longer periods of quiet, seated attention.',
    ),
    Course(
      'introduction-to-yoga',
      'Introduction to Yoga',
      Level.beginner,
      20,
      'studio',
      'Get familiar with foundational poses and simple transitions.',
    ),
    Course(
      'flexibility-yoga',
      'Flexibility Yoga',
      Level.intermediate,
      25,
      'morning',
      'Explore comfortable ranges of motion with supported stretches.',
    ),
    Course(
      'strength-and-balance',
      'Strength and Balance',
      Level.advanced,
      35,
      'balance',
      'Build control through standing sequences and slow transitions.',
    ),
    Course(
      'basic-yoga-poses',
      'Basic Yoga Poses',
      Level.beginner,
      20,
      'studio',
      'Learn how foundational shapes fit into a practice.',
    ),
    Course(
      'surya-namaskar',
      'Surya Namaskar',
      Level.beginner,
      20,
      'morning',
      'Get familiar with the Sun Salutation sequence.',
    ),
    Course(
      'breathing-basics',
      'Breathing Basics',
      Level.beginner,
      12,
      'balance',
      'Notice the natural rhythm of your breath.',
    ),
    Course(
      'relaxation-yoga',
      'Relaxation Yoga',
      Level.beginner,
      15,
      'studio',
      'Make space for rest through supported poses.',
    ),
    Course(
      'strength-yoga',
      'Strength Yoga',
      Level.intermediate,
      24,
      'morning',
      'Explore steady movement and muscular engagement.',
    ),
    Course(
      'intermediate-asanas',
      'Intermediate Asanas',
      Level.intermediate,
      30,
      'studio',
      'Build on foundational poses with more varied transitions.',
    ),
    Course(
      'meditation-practice',
      'Meditation Practice',
      Level.intermediate,
      20,
      'balance',
      'Practice returning your attention to a simple point of focus.',
    ),
    Course(
      'advanced-yoga-poses',
      'Advanced Yoga Poses',
      Level.advanced,
      40,
      'studio',
      'Explore the preparation involved in more demanding poses.',
    ),
    Course(
      'advanced-flexibility',
      'Advanced Flexibility',
      Level.advanced,
      35,
      'morning',
      'Learn about mobility and control at the edges of your range.',
    ),
    Course(
      'advanced-breathing-techniques',
      'Advanced Breathing Techniques',
      Level.advanced,
      25,
      'balance',
      'An overview of advanced practices best learned with a qualified instructor.',
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
