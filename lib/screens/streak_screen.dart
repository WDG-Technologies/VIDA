import 'package:flutter/material.dart';
import '../data/streak.dart';
import '../theme/app_theme.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int _streak = 0;
  int _best = 0;
  Set<String> _dates = {};
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _load();
  }

  Future<void> _load() async {
    final count = await StreakService.getCount();
    final best = await StreakService.getBest();
    final dates = await StreakService.getDates();
    if (!mounted) return;
    setState(() {
      _streak = count;
      _best = best;
      _dates = dates;
    });
  }

  void _prevMonth() => setState(
        () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1),
      );

  void _nextMonth() => setState(
        () => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1),
      );

  @override
  Widget build(BuildContext context) {
    final today = _dateStr(DateTime.now());
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_viewMonth.year, _viewMonth.month, 1).weekday;
    final canGoNext = _viewMonth.year < DateTime.now().year ||
        (_viewMonth.year == DateTime.now().year &&
            _viewMonth.month < DateTime.now().month);

    return Scaffold(
      appBar: AppBar(title: const Text('Racha')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streak días',
                        style: TextStyle(fontFamily: 'Cormorant Garamond', 
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald600,
                        ),
                      ),
                      Text(
                        'Tu mejor racha: $_best días',
                        style: TextStyle(fontFamily: 'DM Sans', 
                          fontSize: 13,
                          color: AppColors.emerald700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.local_fire_department_rounded,
                    size: 36, color: AppColors.amber400),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded),
                  color: AppColors.emerald600,
                  onPressed: _prevMonth,
                ),
                Text(
                  _monthName(_viewMonth.month).toUpperCase(),
                  style: TextStyle(fontFamily: 'DM Sans', 
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald900,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded),
                  color: canGoNext ? AppColors.emerald600 : AppColors.emerald200,
                  onPressed: canGoNext ? _nextMonth : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              children: [
                for (final label in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Center(
                    child: Text(
                      label,
                      style: TextStyle(fontFamily: 'DM Sans', 
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald500,
                      ),
                    ),
                  ),
                for (int i = 1; i < firstWeekday; i++)
                  const SizedBox.shrink(),
                for (int d = 1; d <= daysInMonth; d++) ...[
                  (() {
                    final date =
                        _dateStr(DateTime(_viewMonth.year, _viewMonth.month, d));
                    final isActive = _dates.contains(date);
                    final isToday = date == today;
                    return AnimatedContainer(
                      duration: Duration.zero,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.emerald100
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$d',
                          style: TextStyle(fontFamily: 'DM Sans', 
                            fontSize: 13,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday
                                ? AppColors.emerald700
                                : isActive
                                    ? AppColors.emerald800
                                    : AppColors.emerald400,
                          ),
                        ),
                      ),
                    );
                  })(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _monthName(int m) =>
      [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
      ][m - 1];
}
