import 'package:flutter/widgets.dart';

import 'tenant_config.dart';

/// Simple scope to expose [TenantConfig] to the widget tree.
class TenantScope extends InheritedWidget {
  final TenantConfig config;

  const TenantScope({
    super.key,
    required this.config,
    required Widget child,
  }) : super(child: child);

  static TenantScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TenantScope>();
  }

  @override
  bool updateShouldNotify(TenantScope oldWidget) =>
      oldWidget.config != config;
}

