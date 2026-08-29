/// Notification texts for plant care reminders
/// Each task type has 4 different text variations that rotate
class ReminderNotificationTexts {
  // Watering the plant texts
  static const List<String> wateringTexts = [
    'Your plant is getting thirsty! Time for a refreshing drink. 💧🌱',
    'Watering time! A little hydration goes a long way.',
    'Time to water your plant.',
    'Your plant needs watering to stay healthy.',
  ];

  // Adding fertilizer texts
  static const List<String> fertilizerTexts = [
    'Nutrient boost time! Help your plant grow stronger today. 🌿✨',
    'Your plant could use a little feeding. Add some fertilizer!',
    'Add fertilizer today.',
    'It\'s time to add fertilizer for stronger growth.',
  ];

  // Soil check texts
  static const List<String> soilCheckTexts = [
    'Quick soil check needed! Healthy roots start with healthy soil. 🌱🪴',
    'Take a moment to inspect the soil - your plant will thank you!',
    'Check your plant\'s soil.',
    'A soil check is due. Ensure it\'s in good condition.',
  ];

  // Cutting the plant texts
  static const List<String> cuttingTexts = [
    'It\'s trimming time! A small cut keeps growth healthy and neat. ✂️🌿',
    'Your plant is ready for a little grooming. Time to cut back!',
    'Trim your plant today.',
    'Trim your plant to maintain healthy growth.',
  ];

  // Repotting texts
  static const List<String> repottingTexts = [
    'Your plant needs more space! Consider repotting today. 💚',
    'Growth alert! It might be time to move your plant to a bigger home.',
    'Your plant needs repotting.',
    'Your plant may need more space. Consider repotting',
  ];

  // Pest control texts
  static const List<String> pestControlTexts = [
    'Check for pests! Early care keeps your plant safe and healthy. 🐛🌱',
    'A quick pest check can make a big difference. Take a look!',
    'Check for pests.',
    'Please inspect your plant for possible pests',
  ];

  // Pruning texts
  static const List<String> pruningTexts = [
    'Time to prune! Encourage fresh, healthy growth. ✂️🍃',
    'Pruning reminder: Remove old leaves to flourish the new ones.',
    'Prune your plant today.',
    'Pruning now will support fresh new growth',
  ];

  // Misting texts
  static const List<String> mistingTexts = [
    'Your plant is craving some humidity - give it a light mist. 💦🌿',
    'Misting moment! Keep your plant fresh and hydrated.',
    'Give your plant a light mist.',
    'Your plant could benefit from a light mist.',
  ];

  /// Get notification text for a task type with rotation
  /// Uses reminder ID hash to ensure consistent rotation per reminder
  static String getNotificationText(String taskType, String plantName, String reminderId) {
    final taskTypeLower = taskType.toLowerCase();
    List<String> texts;
    
    // Map task types to their text arrays
    if (taskTypeLower.contains('water')) {
      texts = wateringTexts;
    } else if (taskTypeLower.contains('fertil')) {
      texts = fertilizerTexts;
    } else if (taskTypeLower.contains('soil') || taskTypeLower == 'soil check') {
      texts = soilCheckTexts;
    } else if (taskTypeLower.contains('cutting') || taskTypeLower.contains('trim')) {
      texts = cuttingTexts;
    } else if (taskTypeLower.contains('repotting') || taskTypeLower == 'repotting') {
      texts = repottingTexts;
    } else if (taskTypeLower.contains('pest') || taskTypeLower == 'pest control') {
      texts = pestControlTexts;
    } else if (taskTypeLower.contains('pruning') || taskTypeLower == 'pruning') {
      texts = pruningTexts;
    } else if (taskTypeLower.contains('misting') || taskTypeLower == 'misting') {
      texts = mistingTexts;
    } else {
      // Fallback for unknown task types
      return 'Time to ${taskType.toLowerCase()} your $plantName';
    }

    // Use reminder ID hash to select a text (ensures consistency per reminder)
    // This creates rotation based on the reminder ID
    final index = reminderId.hashCode.abs() % texts.length;
    return texts[index];
  }
}

