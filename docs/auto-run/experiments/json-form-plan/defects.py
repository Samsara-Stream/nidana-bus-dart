"""Seed one defect into the final draft's codec.dart, in place.

usage: python3 -I defects.py <codec.dart> <defect id>
Each defect is one exact replacement that must apply exactly once.
"""
import sys

DEFECTS = {
    # encoder
    "D1": ("    if (dedup != null) 'dedup': dedup.name,\n",
           "    'dedup': dedup?.name,\n"),  # dedup written as null when the read gave none
    "D2": ("  if (edge.output case final TopicRef output) 'output': _encodeTopic(output),\n"
           "  if (edge.transformer case final FunctionRef transformer)\n"
           "    'transformer': _encodeFunction(transformer),\n",
           "  if (edge.transformer case final FunctionRef transformer)\n"
           "    'transformer': _encodeFunction(transformer),\n"
           "  if (edge.output case final TopicRef output) 'output': _encodeTopic(output),\n"),  # transformer before output
    "D3": ("      '${_indented.convert(encodeTopologyGraph(graph))}\\n';\n",
           "      _indented.convert(encodeTopologyGraph(graph));\n"),  # no newline at the end
    "D4": ("const JsonEncoder _indented = JsonEncoder.withIndent('  ');\n",
           "const JsonEncoder _indented = JsonEncoder.withIndent('    ');\n"),  # four spaces
    "D5": ("    'durationMicros': duration.inMicroseconds,\n",
           "    'durationMicros': duration.inMilliseconds,\n"),  # milliseconds
    # decoder
    "D6": ("  _checkDistinctIds(topologies, '$path.topologies');\n", ""),  # repeated ids collapse
    "D7": ("  final List<TopicRef> topics = _list(json, path, _decodeTopic);\n"
           "  final Map<TopicRef, int> first = <TopicRef, int>{};\n",
           "  final List<TopicRef> topics = _list(json, path, _decodeTopic);\n"
           "  return topics;\n"
           "  final Map<TopicRef, int> first = <TopicRef, int>{};\n"),  # no repeat check anywhere
    "D8": ("  final List<TopicRef> writes = _decodeTopics(claim['writes'], '$path.writes');\n",
           "  final List<TopicRef> writes = _list(claim['writes'], '$path.writes', _decodeTopic);\n"),  # a claim's repeats collapse
    "D9": ("  _checkSameTopics(reads, definition.reads, '$path.reads', 'the edges read');\n", ""),  # reads not compared
    "D10": ("  if (topic.variant != TopicVariant.state) {\n",
            "  if (topic.variant == TopicVariant.event) {\n"),  # a dedup on a replay read accepted
    "D11": ("  if (typeName.isEmpty) {\n", "  if (typeName.isEmpty && name.isEmpty) {\n"),  # empty typeName accepted
    "D12": ("  final int n when n >= 0 => n,\n", "  final int n => n,\n"),  # negative index reaches StageInput's assert
    "D13": ("  final double d when d >= 0 && d < _twoTo63 && d == d.truncateToDouble() =>\n",
            "  final double d when false && d == d.truncateToDouble() =>\n"),  # a whole-number double rejected
    "D14": ("  try {\n    return build();\n  } on ArgumentError catch (error) {\n"
            "    _reject(path, '${error.name}: ${error.message}');\n  }\n",
            "  return build();\n"),  # factories' ArgumentError leaks
    "D15": ("    (json is String ? values.asNameMap()[json] : null) ??\n",
            "    (json is String ? values.byName(json) : null) ??\n"),  # unknown name throws ArgumentError
    "D16": ("    _reject(path, 'must be an object');\n",
            "    _reject(path, 'must be an object, not ${jsonEncode(json)}');\n"),  # a message that renders the value
    "D17": ("    () => TopologyGraph(topologies: topologies, claims: claims),\n",
            "    () => TopologyGraph(topologies: topologies, claims: claims.toSet()),\n"),  # equal claims merged
}

path, defect = sys.argv[1], sys.argv[2]
old, new = DEFECTS[defect]
text = open(path).read()
n = text.count(old)
if n != 1:
    sys.exit(f"{defect}: expected one occurrence, found {n}")
open(path, "w").write(text.replace(old, new))
