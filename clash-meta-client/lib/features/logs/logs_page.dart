import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../core/profile.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';

/// 连接日志：流式列表 + 按结果过滤。
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  int _filter = 0;

  static const List<String> _filters = <String>['全部', '已代理', '直连', '已拒绝'];

  bool _matches(LogEntry entry) {
    switch (_filter) {
      case 1:
        return entry.verdict == LogVerdict.proxied;
      case 2:
        return entry.verdict == LogVerdict.direct;
      case 3:
        return entry.verdict == LogVerdict.rejected;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final List<LogEntry> items = c.logs.where(_matches).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TideSpace.page,
              TideSpace.x2,
              TideSpace.page,
              TideSpace.x1,
            ),
            child: Row(
              children: <Widget>[
                Expanded(child: Text('日志', style: text.displaySmall)),
                if (c.usingSimulator)
                  TideBadge(text: '演示数据', color: colors.warning),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
              itemCount: _filters.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: TideSpace.x2),
              itemBuilder: (BuildContext context, int index) {
                final bool selected = _filter == index;
                return GestureDetector(
                  onTap: () => setState(() => _filter = index),
                  child: AnimatedContainer(
                    duration: context.motion(TideMotion.quick),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TideSpace.x3,
                      vertical: TideSpace.x2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? colors.accent : colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(TideRadii.full),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _filters[index],
                      style: TideType.caption.copyWith(
                        color: selected ? Colors.white : colors.inkSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: TideSpace.x2),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      c.tunnelState.isConnected ? '还没有匹配的日志' : '连接后会在这里看到实时连接',
                      style: text.bodySmall,
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Hairline(inset: TideSpace.page),
                    itemBuilder: (BuildContext context, int index) {
                      return _LogRow(entry: items[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    final Color dot;
    switch (entry.verdict) {
      case LogVerdict.proxied:
        dot = colors.success;
        break;
      case LogVerdict.direct:
        dot = colors.info;
        break;
      case LogVerdict.rejected:
        dot = colors.danger;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TideSpace.page,
        vertical: TideSpace.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: TideSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.rule}  →  ${entry.outbound}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TideType.mono.copyWith(color: colors.inkSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: TideSpace.x2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(formatBytes(entry.bytes), style: TideType.mono),
              const SizedBox(height: 2),
              Text(_clock(entry.time), style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime time) {
    final String h = time.hour.toString().padLeft(2, '0');
    final String m = time.minute.toString().padLeft(2, '0');
    final String s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
