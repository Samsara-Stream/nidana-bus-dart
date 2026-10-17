// covers: G2
// The adapter's types are final: none can be extended or implemented outside
// the package, so every widget, router, observer and helper an app holds is
// the package's own.
import 'package:nidana_dart_runtime_flutter/nidana_dart_runtime_flutter.dart';
import 'package:nidana_dart_runtime_flutter/testing.dart';

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnProvider implements BusProvider {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnStateBuilder implements StateTopicBuilder<int> {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnReplayBuilder implements ReplayTopicBuilder<int> {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnPageScope implements PageScope {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnModuleRoutes implements ModuleRoutes {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnModuleObserver implements ModuleScopeObserver {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnRouter implements FlutterNavigationRouter {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnExecutor implements FlutterNavigationExecutor {}

// expect-diagnostic: invalid_use_of_type_outside_library
abstract final class OwnTestBus implements WidgetTestBus {}
