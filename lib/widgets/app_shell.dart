import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../state/providers.dart';
import 'app_sidebar.dart';
import 'app_topbar.dart';

/// Sidebar + top bar frame that wraps every page.
///
/// * `< 1024px` — sidebar becomes a drawer
/// * `>= 1024px` — sidebar is docked, expanded or collapsed to an icon rail
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _appliedInitialCollapse = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start collapsed on smaller laptops; the user can pin it open after that.
    if (!_appliedInitialCollapse) {
      _appliedInitialCollapse = true;
      final width = MediaQuery.sizeOf(context).width;
      if (width < Breakpoints.laptop && ref.read(sidebarPinnedProvider)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ref.read(sidebarPinnedProvider.notifier).toggle();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final useDrawer = context.useDrawerNav;
    final pinned = ref.watch(sidebarPinnedProvider);

    final content = Column(
      children: [
        AppTopBar(
          currentPath: widget.location,
          onLeadingTap: () {
            if (useDrawer) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              ref.read(sidebarPinnedProvider.notifier).toggle();
            }
          },
        ),
        Expanded(child: widget.child),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.canvas,
      drawer: useDrawer
          ? Drawer(
              width: AppSidebar.expandedWidth,
              child: AppSidebar(
                mode: SidebarMode.drawer,
                currentPath: widget.location,
                onNavigate: () => Navigator.of(context).maybePop(),
              ),
            )
          : null,
      body: useDrawer
          ? content
          : Row(
              children: [
                AppSidebar(
                  mode: pinned ? SidebarMode.expanded : SidebarMode.rail,
                  currentPath: widget.location,
                ),
                Expanded(child: content),
              ],
            ),
    );
  }
}

/// Scrollable page body with the right gutters for the current breakpoint.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.maxWidth = 1320,
    this.padding,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final gutter = context.pageGutter;
    final top = context.responsive<double>(mobile: 20, tablet: 24, laptop: 28);
    return SingleChildScrollView(
      padding: padding ??
          EdgeInsets.fromLTRB(
            gutter,
            top,
            gutter,
            top + 40 + MediaQuery.paddingOf(context).bottom,
          ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
