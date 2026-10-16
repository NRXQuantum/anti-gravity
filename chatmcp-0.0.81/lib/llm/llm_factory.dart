import 'openai_client.dart';
import 'claude_client.dart';
import 'deepseek_client.dart';
import 'base_llm_client.dart';
import 'ollama_client.dart';
import 'gemini_client.dart';
import 'foundry_client.dart';
import 'copilot_client.dart';
import 'claude_code_client.dart';
import 'package:chatmcp/provider/provider_manager.dart';
import 'package:chatmcp/provider/settings_provider.dart';
import 'package:logging/logging.dart';
import 'model.dart' as llm_model;

enum LLMProvider {
  openai,
  claude,
  ollama,
  ollamaCloud,
  omniroute,
  deepseek,
  gemini,
  foundry,
  claudeCode,
  copilot,
}

class LLMFactory {
  static BaseLLMClient create(
    LLMProvider provider, {
    required String apiKey,
    required String baseUrl,
    String? apiVersion,
  }) {
    switch (provider) {
      case LLMProvider.openai:
        return OpenAIClient(apiKey: apiKey, baseUrl: baseUrl);
      case LLMProvider.claude:
        return ClaudeClient(apiKey: apiKey, baseUrl: baseUrl);
      case LLMProvider.claudeCode:
        return ClaudeCodeClient();
      case LLMProvider.deepseek:
        return DeepSeekClient(apiKey: apiKey, baseUrl: baseUrl);
      case LLMProvider.ollama:
        return OllamaClient(baseUrl: baseUrl);
      case LLMProvider.ollamaCloud:
        return OllamaClient(baseUrl: baseUrl, apiKey: apiKey, isCloud: true);
      case LLMProvider.omniroute:
        return OpenAIClient(apiKey: apiKey, baseUrl: baseUrl);
      case LLMProvider.gemini:
        return GeminiClient(apiKey: apiKey, baseUrl: baseUrl);
      case LLMProvider.foundry:
        return FoundryClient(
          apiKey: apiKey,
          baseUrl: baseUrl,
          apiVersion: apiVersion,
        );
      case LLMProvider.copilot:
        return CopilotClient(apiKey: apiKey);
    }
  }
}

class LLMFactoryHelper {
  static final nonChatModelKeywords = {
    "whisper",
    "tts",
    "dall-e",
    "embedding",
  };

  static bool isChatModel(llm_model.Model model) {
    return !nonChatModelKeywords.any((keyword) => model.name.contains(keyword));
  }

  static final Map<String, LLMProvider> providerMap = {
    "openai": LLMProvider.openai,
    "claude": LLMProvider.claude,
    "claude-code": LLMProvider.claudeCode,
    "deepseek": LLMProvider.deepseek,
    "ollama": LLMProvider.ollama,
    "ollama-cloud": LLMProvider.ollamaCloud,
    "omniroute": LLMProvider.omniroute,
    "gemini": LLMProvider.gemini,
    "foundry": LLMProvider.foundry,
    "copilot": LLMProvider.copilot,
  };

  static String _maskApiKey(String apiKey) {
    if (apiKey.isEmpty) return 'empty';
    if (apiKey.length <= 8) return '***';
    return '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}';
  }

  static void _logApiKeyUsage(String provider, String model, String apiKey) {
    final maskedKey = _maskApiKey(apiKey);
    Logger.root.info(
      'Using API key for provider: $provider, model: $model, key: $maskedKey',
    );
  }

  static LLMProvider _resolveProvider(String providerId, String apiStyle) {
    final mappedProvider = providerMap[providerId];
    if (mappedProvider != null) {
      return mappedProvider;
    }

    try {
      return LLMProvider.values.byName(apiStyle);
    } catch (_) {
      Logger.root.warning(
        'Unknown apiStyle: $apiStyle for provider: $providerId, fallback to openai',
      );
      return LLMProvider.openai;
    }
  }

  static BaseLLMClient createFromModel(llm_model.Model currentModel) {
    final setting = ProviderManager.settingsProvider.apiSettings.firstWhere(
      (element) => element.providerId == currentModel.providerId,
      orElse: () => LLMProviderSetting(
        apiKey: '',
        apiEndpoint: '',
        providerId: currentModel.providerId,
      ),
    );

    final isEnabled = setting.enable ?? true;
    if (!isEnabled) {
      throw Exception('Provider ${currentModel.providerId} is disabled');
    }

    final apiKey = setting.apiKey;
    final baseUrl = setting.apiEndpoint;

    _logApiKeyUsage(currentModel.providerId, currentModel.name, apiKey);

    final provider = _resolveProvider(
      currentModel.providerId,
      currentModel.apiStyle,
    );

    return LLMFactory.create(
      provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      apiVersion: setting.apiVersion,
    );
  }
}
