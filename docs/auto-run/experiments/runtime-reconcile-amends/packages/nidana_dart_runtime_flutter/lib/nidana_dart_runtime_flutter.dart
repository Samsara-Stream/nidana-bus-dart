/// Stand-in for the main library of `nidana_dart_runtime_flutter`
/// (experiment only): the flutter-binding@v1 Interface.
library;

export 'src/bus_provider.dart' show BusProvider;
export 'src/module_scope.dart' show ModuleRoutes, ModuleScopeObserver;
export 'src/navigation.dart'
    show FlutterNavigationExecutor, FlutterNavigationRouter, NavigationRouteBuilder;
export 'src/page_scope.dart' show PageScope;
export 'src/topic_builders.dart' show ReplayTopicBuilder, StateTopicBuilder;
