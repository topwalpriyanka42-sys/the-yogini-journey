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
  const BreathPractice(
    this.courseId,
    this.name,
    this.description,
    this.instructions,
  );

  final String courseId;
  final String name;
  final String description;
  final List<String> instructions;
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

const breathPractices = [
  BreathPractice(
    'pranayama-deep-breathing',
    'Deep Breathing',
    'Explore a gentle, comfortable breath.',
    [
      'आराम से बैठें और कंधे ढीले छोड़ें।',
      'नाक से धीरे साँस लें। पेट और पसलियों को सहजता से फैलने दें।',
      'बिना साँस रोके धीरे छोड़ें। कुछ सहज साँसों तक दोहराएँ।',
    ],
  ),
  BreathPractice(
    'pranayama-bhramari',
    'Bhramari',
    'Get to know the humming breath.',
    [
      'आराम से बैठें और जबड़ा ढीला छोड़ें।',
      'नाक से सहज साँस लें। साँस छोड़ते हुए होंठ हल्के बंद रखकर धीमी «म्» की आवाज़ करें।',
      'जब सहज लगे, आवाज़ रोककर सामान्य साँस लें। कुछ बार आराम से दोहराएँ।',
    ],
  ),
  BreathPractice(
    'pranayama-anulom-vilom',
    'Anulom Vilom',
    'Explore gentle alternate-nostril breathing.',
    [
      'सीधे और आराम से बैठें। दाएँ नथुने को हल्के से बंद करके बाएँ से सहज साँस लें।',
      'बायाँ नथुना हल्के से बंद करें, दायाँ खोलें और साँस छोड़ें। दाएँ से ही सहज साँस लें।',
      'दायाँ बंद करके बाएँ से साँस छोड़ें। बीच में साँस रोके बिना आराम से अभ्यास करें।',
    ],
  ),
  BreathPractice(
    'pranayama-nadi-shodhana',
    'Nadi Shodhana',
    'Learn a gentle form of alternate-nostril breathing.',
    [
      'आराम से बैठकर कुछ सामान्य साँसें लें।',
      'दायाँ नथुना हल्के से बंद कर बाएँ से साँस लें। फिर बायाँ बंद कर दाएँ से छोड़ें।',
      'दाएँ से साँस लें और बाएँ से छोड़ें। लय सहज रखें और साँस रोकने की कोशिश न करें।',
    ],
  ),
  BreathPractice(
    'pranayama-ujjayi',
    'Ujjayi',
    'Meet the steady, softly audible breath.',
    [
      'आराम से बैठें और नाक से सहज साँस लें।',
      'साँस छोड़ते हुए गले से हल्की, सम आवाज़ आने दें। गले को कसने की कोशिश न करें।',
      'आवाज़ न बने तो सामान्य साँस पर लौट आएँ। साँस की लंबाई सहज रखें।',
    ],
  ),
  BreathPractice(
    'pranayama-kapalbhati',
    'Kapalbhati',
    'An advanced practice best learned with qualified instruction.',
    [
      'कपालभाति में साँस छोड़ने की क्रिया सक्रिय होती है और अगली साँस सहज आती है।',
      'पहली बार किसी योग्य योग प्रशिक्षक के साथ सीखें। अभ्यास की गति और अवधि उनसे तय करें।',
      'अभ्यास से पहले गर्भावस्था, हाल की सर्जरी या किसी स्वास्थ्य समस्या के बारे में प्रशिक्षक और अपने चिकित्सक से पूछें।',
    ],
  ),
];
