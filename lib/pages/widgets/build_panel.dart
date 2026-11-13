import 'package:flutter/material.dart';

import '../../game/battle_controller.dart';
import '../../game/battle_state.dart';
import '../../game/battle_types.dart';
import '../../game/production_catalog.dart';
import '../../theme/palette.dart';

/// 建造栏：建筑 / 步兵 / 装甲三个分类，展示价格、锁定条件与生产进度。
class BuildPanel extends StatefulWidget {
  const BuildPanel({super.key, required this.controller, this.compact = false});

  final BattleController controller;
  final bool compact;

  @override
  State<BuildPanel> createState() => _BuildPanelState();
}

class _BuildPanelState extends State<BuildPanel> {
  ProductionCategory _tab = ProductionCategory.structure;

  BattleState get _state => widget.controller.state;

  List<ProductionItem> get _items => ProductionCatalog.of(_tab);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final job = _state.jobOf(playerTeam, _tab);
    return Container(
      decoration: BoxDecoration(
        color: hudPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hudBorderGold),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final category in ProductionCategory.values) ...[
                _TabButton(
                  label: category.label,
                  active: category == _tab,
                  busy: _state.jobOf(playerTeam, category) != null,
                  onTap: () => setState(() => _tab = category),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Flexible(
                child: job != null
                    ? _QueueHint(
                        name: job.name,
                        progress: job.progress,
                        onCancel: () => controller.cancelProduction(_tab),
                      )
                    : Text(
                        _hintForTab(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: hudTextFaint),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _BuildCard(
                  item: item,
                  controller: widget.controller,
                  compact: widget.compact,
                  onTap: () => _onTap(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _hintForTab() {
    if (_state.readyStructuresOf(playerTeam).isNotEmpty) {
      return '有建筑待放置';
    }
    return switch (_tab) {
      ProductionCategory.structure => '建筑在指挥中心排产',
      ProductionCategory.infantry => '步兵在兵营训练',
      ProductionCategory.armor => '装甲在战车工厂生产',
    };
  }

  void _onTap(ProductionItem item) {
    final controller = widget.controller;
    final building = item.building;
    if (building != null && _state.hasReadyStructure(playerTeam, building)) {
      controller.beginPlacement(item.id);
      return;
    }
    final job = _state.jobOf(playerTeam, _tab);
    if (job != null) {
      if (job.id == item.id) {
        controller.cancelProduction(_tab);
      } else {
        _state.addNotice('当前${_tab.label}队列正在生产${job.name}', level: NoticeLevel.warning);
      }
      return;
    }
    controller.requestProduction(_tab, item.id);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0x33D9A94B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xAAD9A94B) : const Color(0x334F4A40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? const Color(0xFFF2D79C) : const Color(0xFFAFA595),
              ),
            ),
            if (busy) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: appRed, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueHint extends StatelessWidget {
  const _QueueHint({required this.name, required this.progress, required this.onCancel});

  final String name;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$name ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 11, color: Color(0xFFD9CBB4)),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onCancel,
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.close, size: 13, color: Color(0xFFB9AD9A)),
          ),
        ),
      ],
    );
  }
}

class _BuildCard extends StatelessWidget {
  const _BuildCard({
    required this.item,
    required this.controller,
    required this.onTap,
    this.compact = false,
  });

  final ProductionItem item;
  final BattleController controller;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final building = item.building;
    final job = state.jobOf(playerTeam, item.category);
    final ready = building != null && state.hasReadyStructure(playerTeam, building);
    final lock = state.productionBlocker(playerTeam, item.category, item.id);
    final affordable = state.creditsOf(playerTeam) >= item.cost;
    final active = job != null && job.id == item.id;
    final locked = lock != null;
    final width = compact ? 78.0 : 86.0;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: ready
                    ? const [Color(0xFF5A4520), Color(0xFF33280F)]
                    : const [Color(0xFF2F2C25), Color(0xFF23211C)],
              ),
              border: Border.all(
                color: ready
                    ? hudGoldBright
                    : active
                    ? const Color(0xFFB0663F)
                    : const Color(0x33EFE2C8),
                width: ready ? 1.6 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: compact ? 22 : 24,
                            height: compact ? 22 : 24,
                            decoration: BoxDecoration(
                              color: item.isBuilding
                                  ? const Color(0x33C8382B)
                                  : const Color(0x332F6FA8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.icon,
                              style: TextStyle(
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w700,
                                color: hudText,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (ready) const Icon(Icons.add_circle, size: 14, color: hudGoldBright),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10.5 : 11.5,
                          fontWeight: FontWeight.w600,
                          color: locked ? const Color(0xFF8B8477) : const Color(0xFFECE1CC),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: hudGold, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${item.cost}',
                            style: TextStyle(
                              fontSize: compact ? 10 : 10.5,
                              color: affordable ? hudTextSoft : hudDanger,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (active)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 4,
                      color: const Color(0x44000000),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: job.progress.clamp(0.0, 1.0),
                        child: Container(color: const Color(0xFFE0A24A)),
                      ),
                    ),
                  ),
                if (locked)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: _CardBadge(
                      text: lock,
                      background: const Color(0xCC1B1915),
                      color: const Color(0xFFC9B79B),
                    ),
                  ),
                if (!locked && !affordable && !ready)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 4,
                    child: _CardBadge(
                      text: '资金不足',
                      background: Color(0xAA27120E),
                      color: Color(0xFFFFB4A2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 建造卡片底部的锁定 / 资金不足提示条。
class _CardBadge extends StatelessWidget {
  const _CardBadge({required this.text, required this.background, required this.color});

  final String text;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 2),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 9, color: color),
      ),
    );
  }
}
