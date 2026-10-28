# Derives the intermediate library states of the plan's tasks from the final
# draft (draft/lib/src/topology/*.dart) and the committed files (git HEAD), so
# that run.sh can replay each task's passing step:
#   *.t1.dart  after Task 1 (planOf, the builder form, read, write)
#   handle.t2.dart  after Task 2 (the single-input handle calls)
#   handle.t3.dart, stages.t3.dart  after Task 3 (the multi-input calls)
# Task 4 lands the final files. Run: python3 -I gen_variants.py
import pathlib, re, subprocess, sys
here = pathlib.Path(__file__).resolve().parent
top = here / 'draft' / 'lib' / 'src' / 'topology'
repo = here.parents[3]
def head(name):
    return subprocess.run(['git', '-C', str(repo), 'show', f'HEAD:packages/nidana_dart_contracts/lib/src/topology/{name}'],
                          capture_output=True, text=True, check=True).stdout
def sub(text, old, new, count=1):
    assert text.count(old) == count, (old[:80], text.count(old))
    return text.replace(old, new)

final_handle = (top / 'handle.dart').read_text()
final_stages = (top / 'stages.dart').read_text()
final_builder = (top / 'builder.dart').read_text()
final_plan = (top / 'plan.dart').read_text()

# Task 3's handle: no _accept yet (Task 4).
accept_decl = """
  // Calls the visitor method of this stage's class with this stage, binding
  // its type arguments (G16).
  V _accept<V>(StageVisitor<V> visitor);
"""
handle_t3 = sub(final_handle, accept_decl, '')
(top / 'handle.t3.dart').write_text(handle_t3)

# Task 2's handle: Task 3's, with the withLatestFrom calls still throwing.
committed_handle = head('handle.dart')
def method(text, name):
    m = re.search(r'\n  TopicStream<R> ' + name + r'<[^\n]*\n(?:.*\n)*?  }\n', text)
    assert m, name
    return m.group(0)
def committed_method(name):
    m = re.search(r'\n  TopicStream<R> ' + name + r'<[^\n]*\n(?:.*\n)*?  \) => throw UnimplementedError\(\);\n', committed_handle)
    assert m, name
    return m.group(0)
handle_t2 = handle_t3
for name in ['withLatestFrom', 'withLatestFrom2', 'withLatestFrom3']:
    handle_t2 = sub(handle_t2, method(handle_t2, name), committed_method(name))
(top / 'handle.t2.dart').write_text(handle_t2)

# Task 1's handle: the committed one with the builder link.
handle_t1 = sub(committed_handle, "  TopicStream._();\n", """  TopicStream._(this._builder);

  // The builder whose declaration made this handle, which records every
  // stage derived from it (G14, G15).
  final TopologyBuilder _builder;
""")
(top / 'handle.t1.dart').write_text(handle_t1)

# Task 3's stages: no _accept overrides yet.
stages_t3 = re.sub(r'\n\n  @override\n  V _accept<V>\(StageVisitor<V> visitor\) =>\n?\s*visitor\.[^\n]*\n', '\n', final_stages)
assert '_accept' not in stages_t3
(top / 'stages.t3.dart').write_text(stages_t3)

# Task 1's stages: Task 3's without the typed closures; apply still throws.
stages_t1 = sub(stages_t3, """  CombineStage._(super.builder, this.inputs, this.combiner, this._apply)
    : super._();""", """  CombineStage._(super.builder, this.inputs, this.combiner) : super._();""")
stages_t1 = re.sub(r"\n  // combiner, called at the type arguments of the (?:builder|handle) call that made\n  // this stage\.\n  final R Function\([^\n]*\n", "", stages_t1)
stages_t1 = re.sub(r"  /// Calls combiner with \[values\], the inputs' latest payloads in input order\.\n  R apply\(List<Object\?> values\) \{\n(?:.*\n)*?  \}\n",
                   "  /// Calls combiner with [values], the inputs' latest payloads in input order.\n  R apply(List<Object?> values) => throw UnimplementedError();\n", stages_t1)
stages_t1 = re.sub(r"  R apply\(T value, List<Object\?> latest\) \{\n(?:.*\n)*?  \}\n",
                   "  R apply(T value, List<Object?> latest) => throw UnimplementedError();\n", stages_t1)
stages_t1 = sub(stages_t1, """  WithLatestFromStage._(
    super.builder,
    this.primary,
    this.latest,
    this.combiner,
    this._apply,
  ) : super._();""", """  WithLatestFromStage._(super.builder, this.primary, this.latest, this.combiner)
    : super._();""")
assert '_apply' not in stages_t1
(top / 'stages.t1.dart').write_text(stages_t1)

# Task 1's builder: read, write and the machinery; the rest still throws.
committed_builder = head('builder.dart')
builder_t1 = final_builder
def bmethod(text, sig):
    i = text.index(sig)
    j = text.index('\n  }\n', i) + len('\n  }\n')
    return text[i:j]
def cmethod(sig):
    i = committed_builder.index(sig)
    j = committed_builder.index('throw UnimplementedError();\n', i) + len('throw UnimplementedError();\n')
    return committed_builder[i:j]
for sig in ['  void reduceInto<S, E>(', '  TopicStream<R> combine2<', '  TopicStream<R> combine3<', '  TopicStream<R> combine4<', '  TopicStream<R> combineAll<', '  TopicStream<T> merge<']:
    builder_t1 = sub(builder_t1, bmethod(builder_t1, sig), cmethod(sig))
builder_t1 = sub(builder_t1, bmethod(builder_t1, '  // Throws ArgumentError for an empty input list (G14).\n'), '')
builder_t1 = builder_t1.replace('\n\n\n', '\n\n')
(top / 'builder.t1.dart').write_text(builder_t1)

# Task 1's plan: planOf; the visitors still throw.
committed_plan = head('plan.dart')
plan_t1 = sub(final_plan, """V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    stage._accept(visitor);
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) => sink._accept(visitor);""", """V visitStage<V>(TopicStream<Object?> stage, StageVisitor<V> visitor) =>
    throw UnimplementedError();
V visitSink<V>(PlanSink sink, SinkVisitor<V> visitor) =>
    throw UnimplementedError();""")
(top / 'plan.t1.dart').write_text(plan_t1)
print('variants written')
