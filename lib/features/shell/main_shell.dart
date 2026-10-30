import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../focus/focus_screen.dart';
import '../habits/habits_screen.dart';
import '../home/home_screen.dart';
import '../scheduler/plan_screen.dart';
import '../tasks/tasks_screen.dart';

enum AppTab { home, plan, tasks, habits, focus }

/// Root of the signed-in experience: five primary tabs. Sleep, Progress
/// and Profile & Settings open as full pages from Home.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _tab = AppTab.home;

  void _select(AppTab t) => setState(() => _tab = t);

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      select: _select,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _tab.index,
          children: const [
            HomeScreen(),
            PlanScreen(),
            TasksScreen(),
            HabitsScreen(),
            FocusScreen(),
          ],
        ),
        bottomNavigationBar: _TabBar(current: _tab, onSelect: _select),
      ),
    );
  }
}

/// Lets any screen switch tabs, e.g. Home → "View week".
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.select, required super.child});

  final ValueChanged<AppTab> select;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  static const _icons = {
    AppTab.home: (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
    AppTab.plan: (Icons.calendar_today_outlined, Icons.calendar_today_rounded),
    AppTab.tasks: (Icons.check_circle_outline_rounded, Icons.check_circle_rounded),
    AppTab.habits: (Icons.repeat_rounded, Icons.repeat_rounded),
    AppTab.focus: (Icons.timer_outlined, Icons.timer_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: p.background.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: p.separator, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (final t in AppTab.values)
                    Expanded(
                      child: Semantics(
                        selected: t == current,
                        button: true,
                        label: context.tr('tab.${t.name}'),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(t),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                t == current ? _icons[t]!.$2 : _icons[t]!.$1,
                                size: 24,
                                color: t == current ? p.accent : p.textTertiary,
                              ),
                              const SizedBox(height: 3),
                              ExcludeSemantics(
                                child: Text(
                                  context.tr('tab.${t.name}'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: t == current ? p.accent : p.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
