// Surface fixture for topic-model@v1: topics, topic references, the name
// predicate and scopes, used the way a registry and its consumers use them.
// Passes when `fvm dart analyze --fatal-infos` reports nothing on it.
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

/// An application's state ADT with an Initializing variant (Spec §7.6).
sealed class AuthState {
  const AuthState();
}

final class Initializing extends AuthState {
  const Initializing();
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

final class AuthEvent {
  const AuthEvent(this.kind);
  final String kind;
}

final class ChatMessage {
  const ChatMessage(this.text);
  final String text;
}

final class Session {
  const Session(this.seed);
  final int seed;
}

/// A pure factory for a computed initial value (Spec §2.5).
Session freshSession() => const Session(0);

/// A hand-written registry (Spec §4.2): const declarations.
abstract final class AuthTopics {
  static const StateTopic<AuthState> state = StateTopic<AuthState>(
    name: 'auth.state',
    initial: Initializing(),
    sensitive: true,
  );

  static const EventTopic<AuthEvent> events = EventTopic<AuthEvent>(
    name: 'auth.events',
  );

  static const StateTopic<Session> session = StateTopic<Session>.computed(
    name: 'auth.session',
    initial: freshSession,
    dedup: Dedup.none,
    tracing: Tracing.disabled,
  );
}

/// A generated registry (Guide Appendix C.3): final declarations.
abstract final class ChatTopics {
  static final ReplayTopic<ChatMessage> messages = ReplayTopic<ChatMessage>(
    name: 'chat.messages',
    bufferSize: 50,
  );

  static final EventTopic<ChatMessage> typed = EventTopic<ChatMessage>(
    name: 'chat.message.typed',
    sensitive: false,
    tracing: Tracing.enabled,
  );

  static final StateTopic<int> unread = StateTopic<int>(
    name: 'chat.unread-count',
    initial: 0,
    dedup: Dedup.equality,
    sensitive: false,
    tracing: Tracing.enabled,
  );
}

/// Matching on the closed topic family needs no default case (G1).
String describe(Topic<Object?> topic) => switch (topic) {
      StateTopic<Object?>(dedup: Dedup.equality) => 'state, deduplicated',
      StateTopic<Object?>(dedup: Dedup.none) => 'state, every publish',
      EventTopic<Object?>() => 'event',
      ReplayTopic<Object?>(bufferSize: final int size) => 'replay of $size',
    };

String variantLabel(TopicVariant variant) => switch (variant) {
      TopicVariant.state => 'state',
      TopicVariant.event => 'event',
      TopicVariant.replay => 'replay',
    };

String tracingLabel(Tracing tracing) => switch (tracing) {
      Tracing.enabled => 'traced',
      Tracing.disabled => 'untraced',
    };

/// What a bus reads from a declaration.
Object? firstValue<T>(StateTopic<T> topic) => topic.createInitial();

/// Every member of a topic and of its reference.
List<Object?> readTopic(Topic<Object?> topic) {
  final String name = topic.name;
  final bool sensitive = topic.sensitive;
  final Tracing tracing = topic.tracing;
  final TopicVariant variant = topic.variant;
  final Type valueType = topic.valueType;
  final TopicRef ref = topic.ref;
  final String refName = ref.name;
  final TopicVariant refVariant = ref.variant;
  final String typeName = ref.typeName;
  return <Object?>[
    name,
    sensitive,
    tracing,
    variant,
    valueType,
    refName,
    refVariant,
    typeName,
    topic == AuthTopics.state,
    topic.hashCode,
  ];
}

const TopicRef stateRef = TopicRef(
  name: 'auth.state',
  variant: TopicVariant.state,
  typeName: 'AuthState',
);

final bool wellFormed = isWellFormedTopicName(AuthTopics.state.name);

final AuthState initialAuth = AuthTopics.state.createInitial();
final Session initialSession = AuthTopics.session.createInitial();
final int bufferSize = ChatTopics.messages.bufferSize;
final Dedup unreadDedup = ChatTopics.unread.dedup;

/// Scopes and their order (Spec §7.1, §7.2).
String scopeLabel(Scope scope) => switch (scope) {
      Scope.application => 'application',
      Scope.module => 'module',
      Scope.page => 'page',
    };

bool ownerMayServe(Scope owner, Scope reader) =>
    owner.isAtLeastAsLongAs(reader);

final List<Scope> allScopes = Scope.values;
