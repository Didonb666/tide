import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class GlassLabPage extends StatefulWidget {
  const GlassLabPage({super.key});

  @override
  State<GlassLabPage> createState() => _GlassLabPageState();
}

class _GlassLabPageState extends State<GlassLabPage> {
  double _tint = 0.5;

  @override
  Widget build(BuildContext context) {
    final Brightness b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('液态玻璃实验室')),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/default_background.webp',
              fit: BoxFit.cover,
            ),
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            children: <Widget>[
              _caption('Regular · 圆角 26'),
              LiquidGlassLayer(
                settings: LiquidGlassSettings.ios27Regular(
                  brightness: b,
                  tintAmount: _tint,
                ),
                defaultAppearance:
                    LiquidGlassAppearance.ios27Regular(brightness: b),
                child: LiquidGlass(
                  shape: const LiquidRoundedSuperellipse(borderRadius: 26),
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Fstool 液态玻璃',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '边缘应该能看到背景被弯折、颜色被拆开',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _caption('Clear · 胶囊'),
              LiquidGlassLayer(
                settings: LiquidGlassSettings.ios27Clear(tintAmount: _tint),
                child: LiquidGlass(
                  shape: const LiquidRoundedSuperellipse(borderRadius: 30),
                  child: const SizedBox(width: 200, height: 60),
                ),
              ),
              const SizedBox(height: 26),
              _caption('BlendGroup · 两滴融合'),
              LiquidGlassLayer(
                settings: LiquidGlassSettings.ios27Regular(brightness: b),
                child: LiquidGlassBlendGroup(
                  blend: 22,
                  child: Row(
                    children: const <Widget>[
                      LiquidGlass.grouped(
                        shape: LiquidOval(),
                        child: SizedBox.square(dimension: 56),
                      ),
                      SizedBox(width: 10),
                      LiquidGlass.grouped(
                        shape: LiquidRoundedSuperellipse(borderRadius: 28),
                        child: SizedBox(width: 150, height: 56),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'tintAmount：${_tint.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Slider(
                value: _tint,
                onChanged: (double v) => setState(() => _tint = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _caption(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
