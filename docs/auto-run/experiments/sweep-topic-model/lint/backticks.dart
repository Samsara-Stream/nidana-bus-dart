// topic-model@v1's "Message sources" doc comment as S151 writes it, the text
// of packages/nidana_dart_contracts/lib/src/topic/message_source.dart, copied
// verbatim onto a stand-in declaration.

/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: `'topology:<id>'`, `'service:<name>'`,
/// `'page:<routeOrName>'`, `'executor:<name>'`, `'unknown'`.
abstract final class MessageSourceProbe {}
