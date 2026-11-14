import 'package:flutter/material.dart';

import '../game/battle_types.dart';
import '../theme/app_theme.dart';

/// 玩法说明：目标、经济、建造流程、兵种与操作。
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('玩法说明')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const _Section(
            icon: Icons.flag,
            title: '战役目标',
            children: [
              _Paragraph(
                '遭遇战摧毁蓝军的全部建筑即可获胜；赤军建筑被全部摧毁则失败。'
                '蓝军会不断扩军并成波进攻，稳住经济、及时补防线是关键。',
              ),
              _Paragraph(
                '战役模式共五关：以歼灭战开局，中段穿插斩首行动，'
                '最后一关直取指挥中心。通关后自动解锁下一关。',
              ),
            ],
          ),
          const _Section(
            icon: Icons.radar,
            title: '战争迷雾与雷达',
            children: [
              _Paragraph(
                '战场被战争迷雾覆盖：己方单位与建筑提供视野，未探索区域全黑，'
                '撤出视野后敌军会从画面与迷你地图上消失，只留下已探索的地形。',
              ),
              _Paragraph(
                '指挥中心提供雷达。点击顶部雷达按钮可扫描一次，'
                '4 秒内在迷你地图上标定全部敌军，冷却 45 秒；指挥中心被摧毁后雷达失效。',
              ),
            ],
          ),
          const _Section(
            icon: Icons.paid,
            title: '经济与电力',
            children: [
              _Paragraph(
                '采矿车会自动往返矿区与矿石精炼厂，每次入库都会转化为资金。'
                '开局有两辆采矿车，矿区采空后会自动寻找最近的矿脉。',
              ),
              _Paragraph(
                '电厂提供电力，建筑会消耗电力。电力不足时生产速度与防御塔射速减半，'
                '看到顶部电力变红就优先补电厂。',
              ),
            ],
          ),
          const _Section(
            icon: Icons.construction,
            title: '建造流程',
            children: [
              _Paragraph(
                '① 在下方建造栏选择建筑或单位，资金会立即扣除并开始生产。'
                '② 建筑完成后卡片出现金色标记，点击后进入放置模式。'
                '③ 移动光标或手指选择位置，绿色表示可以建造，点击确认。',
              ),
              _Paragraph(
                '建筑必须靠近己方已有建筑（指挥中心 9 格，其他建筑 7 格）；'
                '水域、岩石与矿石上不能建造。',
              ),
            ],
          ),
          _Section(
            icon: Icons.groups,
            title: '兵种与克制',
            children: [
              for (final (kind, role) in _unitRoles) _UnitRow(kind: kind, role: role),
              const _Paragraph(
                '哨戒炮塔自动攻击射程内的地面目标，适合放在矿区与基地入口；'
                '防空炮塔只打空中目标，射程 9.5 格，是武装直升机的天敌。'
                '工程兵会自动维修附近受损的车辆与建筑；自行火炮射程 11.5 格，但 3 格内无法开火。',
              ),
            ],
          ),
          const _Section(
            icon: Icons.touch_app,
            title: '操作方式',
            children: [
              _Bullet('点选己方单位，再点击地面移动；点击敌军或建筑发起攻击。'),
              _Bullet('拖动空白处平移视角，双指捏合缩放；左上角迷你地图可快速跳转。'),
              _Bullet('桌面端：左键框选、右键下达指令、滚轮缩放、WASD / 方向键平移。'),
              _Bullet('「全选」选中同型部队，「停止」取消当前指令，「定位」把视角移到选中目标。'),
              _Bullet('右上角可以切换 1× / 2× 速度与暂停；Esc 取消放置或打开暂停菜单。'),
            ],
          ),
          const _Section(
            icon: Icons.tips_and_updates,
            title: '开局建议',
            children: [
              _Bullet('先补一座电厂，再建兵营；兵营完成后立刻造 2~3 名步兵防早期骚扰。'),
              _Bullet('尽快建造战车工厂，补充第 3 辆采矿车，经济领先才有装甲优势。'),
              _Bullet('蓝军第一波通常在数分钟内到达，提前在矿区与路口布置炮塔。'),
              _Bullet('攒够 4~6 辆坦克再推进，沿公路走能提高移动速度。'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '提示：本作为纯单机游戏，进度与战绩保存在本地。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF8B8172)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: appRed),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.75)),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 6),
            child: SizedBox(
              width: 4,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(color: appGold, shape: BoxShape.circle),
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.7))),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.kind, required this.role});

  final UnitKind kind;
  final String role;

  @override
  Widget build(BuildContext context) {
    final spec = unitSpecs[kind]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: appRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              spec.name,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(role, style: const TextStyle(fontSize: 12, height: 1.6))),
          const SizedBox(width: 6),
          Text('¥${spec.cost}', style: const TextStyle(fontSize: 11, color: Color(0xFF8B8172))),
        ],
      ),
    );
  }
}

const List<(UnitKind, String)> _unitRoles = [
  (UnitKind.rifle, '廉价主力，清理步兵效果好，对装甲伤害很低。'),
  (UnitKind.rocket, '反装甲核心，射程远，对坦克与建筑效果显著；可对空射击直升机。'),
  (UnitKind.engineer, '无武器，自动维修附近的车辆与建筑，需要部队护送。'),
  (UnitKind.harvester, '自动采矿，无武装。被袭击时尽快派兵驱赶敌军。'),
  (UnitKind.lightTank, '机动快，适合骚扰矿区与追击步兵。'),
  (UnitKind.heavyTank, '高血量高火力，攻坚与正面决战的主力。'),
  (UnitKind.artillery, '远程拆建筑与炮群，贴脸无法开火，靠队友掩护。'),
  (UnitKind.gunship, '无视地形直飞，机炮压制步兵；只会被防空炮塔与火箭兵击落。'),
];
