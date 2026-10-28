// topic-model@v1's "Message sources" doc comment as the contract stood before
// S151, copied verbatim onto a stand-in declaration.

/// Who produced a message (Spec §2.4 `source`). toString() renders the
/// Spec's format: 'topology:<id>', 'service:<name>', 'page:<routeOrName>',
/// 'executor:<name>', 'unknown'.
abstract final class MessageSourceProbe {}
