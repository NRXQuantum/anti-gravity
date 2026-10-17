import 'package:logging/logging.dart';

import '../inmemory/memory_server.dart';
import '../models/json_rpc_message.dart';

class ArtifactServer extends MemoryServer {
  ArtifactServer() : super(name: 'artifact-instructions') {
    addTool(
      Tool(
        name: 'get_artifact_instructions',
        description:
            'Only call this function when you need instructions for a specific artifact type, and call it only once per type. '
            'This tool provides guidance on creating and referencing artifacts, including code, documents, HTML, SVG, Mermaid diagrams, or React components. '
            'Do not call this function repeatedly if instructions or definitions for the requested artifact type are already available in the current context. '
            'Specify the desired artifact category through the type parameter: code, documents, html, svg, mermaid, or react. '
            'After obtaining the instructions, use them appropriately and avoid duplicate calls for the same type.',
        inputSchema: ToolInput(
          type: 'object',
          description: 'Get the artifact instructions',
          properties: [Property(name: 'type', type: ToolInputType.string)],
          required: ['type'],
        ),
      ),
    );
  }

  @override
  Map<String, dynamic> onToolCall(JSONRPCMessage message) {
    String name = message.params?['name'];
    Map<String, dynamic>? arguments = message.params?['arguments'];
    Logger.root.fine('memory_server onToolCall name: $name arguments: $arguments');
    switch (name) {
      case 'get_artifact_instructions':
        String requestedType = (arguments?['type'] ?? '').toString();
        return {'result': getArtifactPromptForType(requestedType)};
      default:
        return {'result': 'unknown tool'};
    }
  }
}

String getArtifactPromptForType(String type) {
  final cleanType = type.trim().toLowerCase();

  String specificExample = '';
  if (cleanType.contains('html')) {
    specificExample = '''

### HTML Artifacts (type="text/html"):
- Create a self-contained HTML file including CSS in `<style>` and JavaScript in `<script>`.
- Example:
<antArtifact identifier="interactive-sim" type="text/html" title="Interactive Simulation">
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>body { font-family: sans-serif; padding: 20px; }</style>
</head>
<body>
  <h1>Interactive Simulation</h1>
  <canvas id="canvas" width="400" height="300"></canvas>
  <button onclick="start()">Run</button>
  <script>function start() { /* code */ }</script>
</body>
</html>
</antArtifact>
''';
  } else if (cleanType.contains('mermaid')) {
    specificExample = '''

### Mermaid Artifacts (type="application/vnd.ant.mermaid"):
- Provide raw Mermaid diagram syntax directly (no code fences).
- Example:
<antArtifact identifier="flow-chart" type="application/vnd.ant.mermaid" title="Process Flow">
graph TD
  A[Start] --> B{Decision}
  B -->|Yes| C[Proceed]
  B -->|No| D[Retry]
  C --> E[Done]
</antArtifact>
''';
  } else if (cleanType.contains('react')) {
    specificExample = '''

### React Artifacts (type="application/vnd.ant.react"):
- Write a clean React component with default export. Use Tailwind CSS for styles.
- Example:
<antArtifact identifier="dashboard-view" type="application/vnd.ant.react" title="Dashboard">
import React, { useState } from 'react';

export default function Dashboard() {
  const [count, setCount] = useState(0);
  return (
    <div className="p-4">
      <h2 className="text-xl font-bold">Counter: {count}</h2>
      <button onClick={() => setCount(count + 1)} className="mt-2 px-4 py-2 bg-blue-500 text-white rounded">
        Click
      </button>
    </div>
  );
}
</antArtifact>
''';
  } else if (cleanType.contains('svg')) {
    specificExample = '''

### SVG Artifacts (type="image/svg+xml"):
- Provide responsive SVG code with viewBox attribute.
- Example:
<antArtifact identifier="vector-graphic" type="image/svg+xml" title="Vector Graphic">
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="45" fill="#4facfe" />
</svg>
</antArtifact>
''';
  } else if (cleanType.contains('code') || cleanType.contains('py') || cleanType.contains('js')) {
    specificExample = '''

### Code Artifacts (type="application/vnd.ant.code"):
- Specify language attribute (e.g., language="python" or language="javascript").
- Example:
<antArtifact identifier="math-script" type="application/vnd.ant.code" language="python" title="Math Calculations">
def calculate(a, b):
    return a + b
</antArtifact>
''';
  }

  return '''<artifact_instructions>
Artifacts are self-contained, substantial, or visual content (code, web pages, diagrams, components) rendered in a dedicated UI window with live preview.

### Syntax Rules:
1. Wrap content in `<antArtifact>` tags.
2. The opening tag MUST be on a single line and MUST end with `>`:
   `<antArtifact identifier="unique-kebab-id" type="TYPE" title="Brief Title">`
3. Always close with `</antArtifact>`.
4. Do NOT use markdown triple backticks around the code inside artifacts (except for markdown documents).
5. Provide complete, runnable code without placeholders or truncation.

### Supported Types:
- `text/html`: Full single-file HTML pages with CSS/JS.
- `application/vnd.ant.mermaid`: Mermaid diagrams (flowchart, sequence, pie).
- `application/vnd.ant.react`: React components (default export, Tailwind).
- `image/svg+xml`: Scalable Vector Graphics with viewBox.
- `application/vnd.ant.code`: Code scripts (include `language="..."`).
- `text/markdown`: Standalone markdown documents.
$specificExample</artifact_instructions>''';
}

String artifactPrompt = getArtifactPromptForType('');
