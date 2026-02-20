import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Message model for chat
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Chatbot service using Groq API (can be switched to OpenAI/Gemini)
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  // API Configuration - Change these for different providers
  static const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';

  // Get API key from .env file
  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? dotenv.env['OPENAI_API_KEY'] ?? '';

  // Model to use (Groq models: llama-3.1-70b-versatile, mixtral-8x7b-32768)
  String get _model => dotenv.env['AI_MODEL'] ?? 'llama-3.1-70b-versatile';

  // API provider (groq or openai)
  String get _provider => dotenv.env['AI_PROVIDER'] ?? 'groq';

  // Conversation history
  final List<ChatMessage> _conversationHistory = [];

  List<ChatMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  // System prompt for HuntSphere context
  static const String _systemPrompt = '''
You are HuntBot, a friendly AI assistant for HuntSphere - a GPS treasure hunt game platform.

=== ABOUT HUNTSPHERE ===
HuntSphere is a mobile app for organizing GPS-based treasure hunt activities. It has two user types:

1. FACILITATOR (Admin/Organizer):
   - Creates activities with checkpoints on a map
   - Sets up tasks at each checkpoint (Quiz, Photo, QR Code)
   - Generates QR codes for participants to join
   - Monitors real-time leaderboard during games
   - Reviews and approves photo submissions
   - Can end activities and see final results

2. PARTICIPANT (Player):
   - Joins activities by scanning QR code
   - Gets auto-assigned to a team (3+ players needed)
   - Navigates to checkpoints using GPS map
   - Completes tasks at checkpoints to earn points
   - Must be within 50 meters of checkpoint to check in
   - Competes for highest score on leaderboard

=== TASK TYPES ===
- Quiz: Answer multiple choice questions correctly
- Photo: Take and submit photos for facilitator approval
- QR Code: Scan hidden QR codes at checkpoint locations

=== GAME FLOW ===
1. Facilitator creates activity and checkpoints
2. Participants join via QR code and wait in lobby
3. Facilitator starts game when ready (min 3 participants)
4. Teams race to complete all checkpoints
5. Points awarded for correct answers and completed tasks
6. Winner = team with most points (tiebreaker: fastest finish time)

=== YOUR ROLE ===
- Help participants understand gameplay
- Give hints WITHOUT revealing direct answers
- Encourage exploration and teamwork
- Explain features when asked
- Be friendly, concise, and use emojis occasionally! 🎯

If asked about specific checkpoint locations or direct task answers, politely decline and encourage them to explore and figure it out themselves.
''';

  /// Send a message and get AI response
  Future<String> sendMessage(String userMessage) async {
    if (_apiKey.isEmpty) {
      return 'API key not configured. Please add GROQ_API_KEY or OPENAI_API_KEY to your .env file.';
    }

    // Add user message to history
    _conversationHistory.add(ChatMessage(role: 'user', content: userMessage));

    try {
      final response = await _callApi(userMessage);

      // Add assistant response to history
      _conversationHistory.add(ChatMessage(role: 'assistant', content: response));

      return response;
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return 'Sorry, I encountered an error. Please try again later.';
    }
  }

  /// Call the AI API
  Future<String> _callApi(String userMessage) async {
    final url = _provider == 'openai' ? _openaiBaseUrl : _groqBaseUrl;

    // Limit conversation history to last 10 messages to avoid token limits
    final recentHistory = _conversationHistory.length > 10
        ? _conversationHistory.sublist(_conversationHistory.length - 10)
        : _conversationHistory;

    // Build messages array with system prompt and conversation history
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...recentHistory.map((m) => m.toJson()),
    ];

    debugPrint('Sending to $url with ${messages.length} messages');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? 'No response';
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return 'API Error: ${response.statusCode}. Please check your API key.';
      }
    } catch (e) {
      debugPrint('Network/Timeout error: $e');
      return 'Network error. Please check your connection.';
    }
  }

  /// Get a hint for a specific task
  Future<String> getHint({
    required String taskType,
    required String taskDescription,
    int hintLevel = 1, // 1 = subtle, 2 = medium, 3 = strong hint
  }) async {
    final hintPrompt = '''
A participant needs a hint for this $taskType task:
"$taskDescription"

Provide a level $hintLevel hint (1=very subtle, 2=medium, 3=more direct but still not the answer).
Keep it encouraging and fun!
''';

    return await sendMessage(hintPrompt);
  }

  /// Generate quiz questions for facilitators
  Future<String> generateQuizQuestions({
    required String topic,
    required int count,
    String difficulty = 'medium',
  }) async {
    final prompt = '''
Generate $count quiz questions about "$topic" for a treasure hunt game.
Difficulty: $difficulty

Format each question as:
Q: [question]
A) [option]
B) [option]
C) [option]
D) [option]
Correct: [letter]

Make them fun and engaging!
''';

    return await sendMessage(prompt);
  }

  /// Suggest activity ideas
  Future<String> suggestActivityIdeas({
    required String location,
    required int teamSize,
    required int duration,
  }) async {
    final prompt = '''
Suggest 3 creative treasure hunt activity ideas for:
- Location: $location
- Team size: $teamSize people per team
- Duration: $duration minutes

Include suggested checkpoint themes and task types (photo, quiz, QR code).
''';

    return await sendMessage(prompt);
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }
}
