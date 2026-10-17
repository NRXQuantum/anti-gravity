import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

// 属性匹配正则表达式
final attributeRegex = RegExp(
  r'''([\w-]+)\s*=\s*(?:["']([^"'>\r\n]*)["']?|([^\s>"']+))''',
  caseSensitive: false,
);

class TagInlineSyntax extends md.InlineSyntax {
  final String tag;

  TagInlineSyntax({required this.tag, bool caseSensitive = false}) : super(_getPattern(tag), caseSensitive: caseSensitive);

  static String _getPattern(String tag) => r'<' + tag + r'\s*([^>]*)>\s*([^<]*)(?:</' + tag + r'\s*([^>]*)>\s*)?';

  Map<String, String> _parseAttributes(String attributeString) {
    final attributes = <String, String>{};
    final matches = attributeRegex.allMatches(attributeString);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        final key = match.group(1) ?? '';
        // 值可能在引号组或无引号组中
        final value = match.group(2) ?? match.group(3) ?? '';
        if (key.isNotEmpty) {
          attributes[key] = value.trim();
        }
      }
    }
    return attributes;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final openingAttributes = _parseAttributes(match[1] ?? '');
    final content = match[2]!.trim();
    final closingAttributes = match[3] != null ? _parseAttributes(match[3]!) : <String, String>{};

    final element = md.Element(tag, [md.Text(content)]);

    // 合并开始和结束标签的属性
    element.attributes.addAll(openingAttributes);
    element.attributes.addAll(closingAttributes);

    element.attributes['content'] = content;
    element.attributes['isInline'] = 'true';
    element.attributes['closed'] = match[3] != null ? 'true' : 'false';

    parser.addNode(element);
    return true;
  }
}

class TagBlockSyntax extends md.BlockSyntax {
  final String tag;

  TagBlockSyntax({required this.tag});

  @protected
  RegExp get startPattern => RegExp(r'^<' + tag + r'(?:[\s>].*|$)', caseSensitive: false);

  @protected
  RegExp get endPattern => RegExp(r'^</' + tag + r'\s*([^>]*)>?\s*$', caseSensitive: false);

  @override
  RegExp get pattern => startPattern;

  Map<String, String> _parseAttributes(String attributeString) {
    final attributes = <String, String>{};
    final matches = attributeRegex.allMatches(attributeString);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        final key = match.group(1) ?? '';
        // 值可能在引号组或无引号组中
        final value = match.group(2) ?? match.group(3) ?? '';
        if (key.isNotEmpty) {
          attributes[key] = value.trim();
        }
      }
    }
    return attributes;
  }

  @override
  bool canParse(md.BlockParser parser) {
    final line = parser.current.content.trimLeft();
    return startPattern.hasMatch(line);
  }

  @override
  md.Node parse(md.BlockParser parser) {
    String firstLine = parser.current.content;
    parser.advance(); // Skip the opening line

    String tagHeader = firstLine;
    // If the opening line does not contain '>', check if next lines continue attributes
    if (!firstLine.contains('>')) {
      while (!parser.isDone) {
        final nextLine = parser.current.content;
        final trimmed = nextLine.trim();
        final isCodeStart = RegExp(
          r'^(?:<!DOCTYPE|<html|<head|<body|<script|<div|<style|import |export |const |let |var |function|def |class |graph |pie |flowchart |sequenceDiagram|```|#)',
          caseSensitive: false,
        ).hasMatch(trimmed);
        final isClosing = RegExp(
          r'^</' + tag,
          caseSensitive: false,
        ).hasMatch(trimmed);
        if (trimmed.isEmpty || isCodeStart || isClosing) {
          break;
        }
        tagHeader += ' $nextLine';
        parser.advance();
        if (nextLine.contains('>')) {
          break;
        }
      }
    }

    // Extract attributes
    String attrStr = tagHeader.replaceFirst(
      RegExp(r'^<' + tag + r'\s*', caseSensitive: false),
      '',
    );
    if (attrStr.endsWith('>')) {
      attrStr = attrStr.substring(0, attrStr.length - 1);
    }
    final openingAttributes = _parseAttributes(attrStr);

    final lines = <String>[];
    bool isClosed = false;
    Map<String, String> closingAttributes = {};

    while (!parser.isDone) {
      final line = parser.current.content;
      final endMatch = endPattern.firstMatch(line.trim());
      if (endMatch != null) {
        isClosed = true;
        closingAttributes = _parseAttributes(endMatch[1] ?? '');
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }

    final content = lines.join('\n');
    md.Element el = md.Element.text(tag, content);

    // 合并开始和结束标签的属性
    el.attributes.addAll(openingAttributes);
    el.attributes.addAll(closingAttributes);

    el.attributes['content'] = content;
    el.attributes['isInline'] = 'false';
    el.attributes['closed'] = isClosed ? 'true' : 'false';
    return el;
  }
}
