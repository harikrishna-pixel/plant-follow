/// Pure helpers for AI Plant Expert. Keeps the attached photo on follow-up
/// questions instead of claiming vision and then dropping the bytes.
class PlantChatLogic {
  PlantChatLogic._();

  static const attachedCopy = 'Photo attached. Ask your question.';
  static const missingCopy =
      "I couldn't open that photo. Try another one.";

  static String botanistPrompt({
    required String question,
    required bool hasImage,
    String? previousQuestion,
  }) {
    final buffer = StringBuffer('You are an expert botanist. ');
    if (hasImage) {
      buffer.write(
        'A botanical photo is included (leaf, flower, whole plant, or similar). Use it. '
        'If you cannot see a photo, say you cannot see it — do not invent one. ',
      );
    } else {
      buffer.write('No photo is included with this message. ');
    }
    final previous = previousQuestion?.trim() ?? '';
    if (previous.isNotEmpty) {
      buffer.write('The user previously asked: "$previous". ');
    }
    buffer.write('Answer this plant question: $question');
    return buffer.toString();
  }

  static bool hasUsableImage(List<int>? bytes) =>
      bytes != null && bytes.isNotEmpty;
}
