import 'package:http/http.dart' as http;
import 'base_llm_client.dart';
import 'dart:convert';
import 'model.dart';
import 'package:logging/logging.dart';

class OllamaClient extends BaseLLMClient {
  final String baseUrl;
  final String apiKey;
  final bool isCloud;
  final Map<String, String> _headers;

  OllamaClient({String? baseUrl, String? apiKey, bool isCloud = false})
    : baseUrl = (baseUrl == null || baseUrl.isEmpty)
          ? 'http://localhost:11434'
          : baseUrl,
      apiKey = apiKey ?? '',
      isCloud = isCloud,
      _headers = {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      };

  
  String get _chatEndpoint =>
      isCloud ? '/api/chat' : '/v1/chat/completions';

  @override
  Future<List<String>> models() async {
    try {
      final httpClient = BaseLLMClient.createHttpClient();
      final response = await httpClient.get(
        Uri.parse("$baseUrl/api/tags"),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final modelsList = data['models'] as List;
      return modelsList
          .map((model) => (model['name'] ?? model['model'] ?? '') as String)
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e, trace) {
      Logger.root.severe('Failed to get model list: $e, trace: $trace');
      return [];
    }
  }

  @override
  Future<LLMResponse> chatCompletion(CompletionRequest request) async {
    final messages = request.messages.map((m) {
      final role = m.role == MessageRole.user ? 'user' : 'assistant';
      return {'role': role, 'content': m.content};
    }).toList();

    final body = <String, dynamic>{
      'model': request.model,
      'messages': messages,
      'stream': false,
    };

    if (request.tools != null && request.tools!.isNotEmpty) {
      body['tools'] = request.tools!;
    }

    final bodyStr = jsonEncode(body);

    try {
      final httpClient = BaseLLMClient.createHttpClient();
      final response = await httpClient.post(
        Uri.parse("$baseUrl$_chatEndpoint"),
        headers: _headers,
        body: bodyStr,
      );

      final responseBody = utf8.decode(response.bodyBytes);
      Logger.root.fine('Ollama request: $bodyStr');
      Logger.root.fine('Ollama response: $responseBody');

      if (response.statusCode >= 400) {
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }

      final jsonData = jsonDecode(responseBody);

      
      
      final message = isCloud
          ? jsonData['message']
          : jsonData['choices'][0]['message'];

      final toolCalls = message['tool_calls']
          ?.map<ToolCall>(
            (t) => ToolCall(
              id: t['id'] ?? '',
              type: 'function',
              function: FunctionCall(
                name: t['function']['name'],
                arguments: jsonEncode(t['function']['arguments']),
              ),
            ),
          )
          ?.toList();

      return LLMResponse(
        content: message['content'] ?? '',
        toolCalls: toolCalls,
      );
    } catch (e) {
      throw await handleError(e, 'Ollama', '$baseUrl$_chatEndpoint', bodyStr);
    }
  }

  @override
  Stream<LLMResponse> chatStreamCompletion(CompletionRequest request) async* {
    final messages = request.messages.map((m) {
      final role = m.role == MessageRole.user ? 'user' : 'assistant';
      return {'role': role, 'content': m.content};
    }).toList();

    final body = <String, dynamic>{
      'model': request.model,
      'messages': messages,
      'stream': true,
    };

    if (request.tools != null && request.tools!.isNotEmpty) {
      body['tools'] = request.tools!;
      body['tool_choice'] = 'auto';
    }

    Logger.root.fine('Ollama request: ${jsonEncode(body)}');

    try {
      final req = http.Request('POST', Uri.parse("$baseUrl$_chatEndpoint"));
      req.headers.addAll(_headers);
      req.body = jsonEncode(body);

      final httpClient = BaseLLMClient.createHttpClient();
      final response = await httpClient.send(req);

      if (response.statusCode >= 400) {
        final responseBody = await response.stream.bytesToString();
        Logger.root.fine('Ollama response: $responseBody');
        throw Exception('HTTP ${response.statusCode}: $responseBody');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        String? jsonStr;
        if (trimmed.startsWith('data: ')) {
          
          jsonStr = trimmed.substring(6).trim();
          if (jsonStr == '[DONE]') continue;
        } else if (isCloud) {
          
          jsonStr = trimmed;
        } else {
          continue;
        }

        if (jsonStr.isEmpty) continue;

        try {
          final json = jsonDecode(jsonStr);

          if (isCloud) {
            final message = json['message'];
            if (message == null) continue;
            final content = message['content'] as String?;
            final toolCalls = message['tool_calls']
                ?.map<ToolCall>(
                  (t) => ToolCall(
                    id: t['id'] ?? '',
                    type: 'function',
                    function: FunctionCall(
                      name: t['function']?['name'] ?? '',
                      arguments:
                          jsonEncode(t['function']?['arguments'] ?? {}),
                    ),
                  ),
                )
                ?.toList();
            final doneReason = json['done'] == true
                ? (json['done_reason'] as String? ?? 'stop')
                : null;
            if ((content != null && content.isNotEmpty) || toolCalls != null || doneReason != null) {
              yield LLMResponse(
                content: content,
                toolCalls: toolCalls,
                finishReason: doneReason,
              );
            }
          } else {
            if (json['choices'] == null || json['choices'].isEmpty) continue;
            final delta = json['choices'][0]['delta'];
            if (delta == null) continue;
            final finishReason = json['choices'][0]['finish_reason'] as String?;

            final toolCalls = delta['tool_calls']
                ?.map<ToolCall>(
                  (t) => ToolCall(
                    id: t['id'] ?? '',
                    type: 'function',
                    function: FunctionCall(
                      name: t['function']?['name'] ?? '',
                      arguments:
                          jsonEncode(t['function']?['arguments'] ?? {}),
                    ),
                  ),
                )
                ?.toList();

            if (delta['content'] != null || toolCalls != null || finishReason != null) {
              yield LLMResponse(
                content: delta['content'],
                toolCalls: toolCalls,
                finishReason: finishReason,
              );
            }
          }
        } catch (e) {
          Logger.root.severe('Failed to parse stream chunk: $jsonStr $e');
          continue;
        }
      }
    } catch (e) {
      throw await handleError(
        e,
        'Ollama',
        "$baseUrl$_chatEndpoint",
        jsonEncode(body),
      );
    }
  }
}
