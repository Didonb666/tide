import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// 拖动时只重建自己，松手才提交到全局 —— 设置页不再每帧全量重建。
class TideSlider extends StatefulWidget {
  const TideSlider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.min = 0,
    required this.divisions,
    required this.format,
    required this.onCommit,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onCommit;

  @override
  State<TideSlider> createState() => _TideSliderState();
}

class _TideSliderState extends State<TideSlider> {
  double? _local;

  double get _value => (_local ?? widget.value).clamp(widget.min, widget.max);

  @override
  void didUpdateWidget(covariant TideSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_local != null && (widget.value - _local!).abs() > 0.0001) {
      _local = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(widget.label, style: text.bodySmall),
            const Spacer(),
            Text(
              widget.format(_value),
              style: TideType.mono.copyWith(color: colors.accent),
            ),
          ],
        ),
        Slider(
          value: _value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          activeColor: colors.accent,
          inactiveColor: colors.surfaceMuted,
          onChanged: (double v) => setState(() => _local = v),
          onChangeEnd: (double v) {
            widget.onCommit(v);
            if (mounted) setState(() => _local = null);
          },
        ),
      ],
    );
  }
}
