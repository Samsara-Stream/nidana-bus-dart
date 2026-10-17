// A topology module that also imports Flutter, as a page file might.
import 'package:flutter/foundation.dart';

const String pageTopologyId = 'payment-form';
bool get flutterLoaded => kDebugMode || !kDebugMode;
